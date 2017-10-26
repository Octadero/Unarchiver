// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

/* Copyright 2017 The Octadero Authors. All Rights Reserved.
 Created by Volodymyr Pavliukevych on 2017.
 
 Licensed under the Apache License 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 https://github.com/Octadero/Unarchiver/blob/master/LICENSE
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import CZlib

/// Compression level whose rawValue is based on the zlib's constants.
/// Compression level in the range of `0` (no compression) to `9` (maximum compression).
public struct CompressionLevel: RawRepresentable {

    public let rawValue: Int32
    
    public static let noCompression = CompressionLevel(Z_NO_COMPRESSION)
    public static let bestSpeed = CompressionLevel(Z_BEST_SPEED)
    public static let bestCompression = CompressionLevel(Z_BEST_COMPRESSION)
    public static let defaultCompression = CompressionLevel(Z_DEFAULT_COMPRESSION)
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: Int32) {
        self.rawValue = rawValue
    }
}


/// Swift Error representation.
/// Errors on gzipping/gunzipping based on the zlib error codes.
/// See public manual http://www.zlib.net/manual.html
public struct ZLibError: Swift.Error {
    public enum Kind {
        
        /// The stream structure was inconsistent.
        /// - underlying zlib error: `Z_STREAM_ERROR` (-2)
        case stream
        
        /// The input data was corrupted (input stream not conforming to the zlib format or incorrect check value).
        /// - underlying zlib error: `Z_DATA_ERROR` (-3)
        case data
        
        /// There was not enough memory.
        /// - underlying zlib error: `Z_MEM_ERROR` (-4)
        case memory

        /// No progress is possible or there was not enough room in the output buffer.
        /// - underlying zlib error: `Z_BUF_ERROR` (-5)
        case buffer
        
        /// The zlib library version is incompatible with the version assumed by the caller.
        /// - underlying zlib error: `Z_VERSION_ERROR` (-6)
        case version
        
        /// An unknown error occurred.
        /// - parameter code: return error by zlib
        case unknown(code: Int)
    }
    
    /// Error kind.
    public let kind: Kind
    
    /// Returned message by zlib.
    public let message: String

    /// Init error from gzip code and message pointer.
    internal init(code: Int32, messagePointer: UnsafePointer<CChar>?) {
        self.message = {
            guard let messagePointer = messagePointer, let message = String(validatingUTF8: messagePointer) else {
                return "Unknown gzip error."
            }
            return message
        }()
        
        self.kind = {
            switch code {
            case Z_STREAM_ERROR:
                return .stream
            case Z_DATA_ERROR:
                return .data
            case Z_MEM_ERROR:
                return .memory
            case Z_BUF_ERROR:
                return .buffer
            case Z_VERSION_ERROR:
                return .version
            default:
                return .unknown(code: Int(code))
            }
        }()
    }
 
    public var localizedDescription: String {
        return "Error code is: \(kind) \"\(self.message)\""
    }
}

/// Data extension to zip & uzip data in memory.
public extension Data {
    
    private struct DataSize {
        static let chunk = 2 ^ 14
        static let stream = MemoryLayout<z_stream>.size
        private init() { }
    }
    
    /// Whether the data is compressed in gzip format.
    public var isGzipped: Bool {
        /// check magic number, see documentation.
        return self.starts(with: [0x1f, 0x8b])
    }
    
    /// Create a new `Data` object by compressing the receiver using zlib.
    /// Throws an error if compression failed.
    /// - Parameters level: Compression level.
    /// - throws: `ZLibError`
    /// - Returns: Gzip-compressed `Data` object.
    public func gzipped(level: CompressionLevel = .defaultCompression) throws -> Data {
        
        guard !self.isEmpty else {
            return Data()
        }
        
        var stream = self.zStream()
        var status: Int32
        
        status = deflateInit2_(&stream, level.rawValue, Z_DEFLATED, MAX_WBITS + 16, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(DataSize.stream))
        
        guard status == Z_OK else {
            // deflateInit2 returns:
            // Z_VERSION_ERROR  The zlib library version is incompatible with the version assumed by the caller.
            // Z_MEM_ERROR      There was not enough memory.
            // Z_STREAM_ERROR   A parameter is invalid.
            
            throw ZLibError(code: status, messagePointer: stream.msg)
        }
        
        var data = Data(capacity: DataSize.chunk)
        while stream.avail_out == 0 {
            if Int(stream.total_out) >= data.count {
                data.count += DataSize.chunk
            }
            
            data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Bytef>) in
                stream.next_out = bytes.advanced(by: Int(stream.total_out))
            }
            
            stream.avail_out = uInt(data.count) - uInt(stream.total_out)
            deflate(&stream, Z_FINISH)
        }
        
        deflateEnd(&stream)
        data.count = Int(stream.total_out)
        
        return data
    }
    
    /// Create a new `Data` object by decompressing the receiver using zlib.
    /// Throws an error if decompression failed.
    /// - throws: `ZLibError`
    /// - Returns: Gzip-decompressed `Data` object.
    public func gunzipped() throws -> Data {
        guard self.isGzipped else {
            return self
        }
        
        guard !self.isEmpty else {
            return Data()
        }
        
        var stream = self.zStream()
        var status: Int32
        
        status = inflateInit2_(&stream, MAX_WBITS + 32, ZLIB_VERSION, Int32(DataSize.stream))
        
        guard status == Z_OK else {
            // inflateInit2 returns:
            // Z_VERSION_ERROR   The zlib library version is incompatible with the version assumed by the caller.
            // Z_MEM_ERROR       There was not enough memory.
            // Z_STREAM_ERROR    A parameters are invalid.
            
            throw ZLibError(code: status, messagePointer: stream.msg)
        }
        
        var data = Data(capacity: self.count * 2)
        
        repeat {
            if Int(stream.total_out) >= data.count {
                data.count += self.count / 2
            }
            
            data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Bytef>) in
                stream.next_out = bytes.advanced(by: Int(stream.total_out))
            }
            stream.avail_out = uInt(data.count) - uInt(stream.total_out)
            
            status = inflate(&stream, Z_SYNC_FLUSH)
            
        } while status == Z_OK
        
        guard inflateEnd(&stream) == Z_OK && status == Z_STREAM_END else {
            // inflate returns:
            // Z_DATA_ERROR   The input data was corrupted (input stream not conforming to the zlib format or incorrect check value).
            // Z_STREAM_ERROR The stream structure was inconsistent (for example if next_in or next_out was NULL).
            // Z_MEM_ERROR    There was not enough memory.
            // Z_BUF_ERROR    No progress is possible or there was not enough room in the output buffer when Z_FINISH is used.
            
            throw ZLibError(code: status, messagePointer: stream.msg)
        }
        
        data.count = Int(stream.total_out)
        
        return data
    }
    
    /// Allocate z_stream_s structure
    private func zStream() -> z_stream {
        var stream = z_stream()
        self.withUnsafeBytes { (bytes: UnsafePointer<Bytef>) in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: bytes)
        }
        stream.avail_in = uint(self.count)
        return stream
    }
    
}
