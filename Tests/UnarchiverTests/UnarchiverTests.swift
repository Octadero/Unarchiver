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

import XCTest
import Unarchiver

class UnarchiverTests: XCTestCase {
    
    func testZipUZip() {
        
        let value = "That is my test raw string, really big big long long long string. That is my test raw string, really big big long long long string. That is my test raw string, really big big long long long string. That is my test raw string, really big big long long long string. That is my test raw string, really big big long long long string. That is my test raw string, really big big long long long string."
        
        guard let clearData = value.data(using: .utf8) else { XCTFail(); return }
        do {
            let zippedData = try clearData.gzipped(level: CompressionLevel.bestSpeed)
            let zippedSize = zippedData.count
            
            guard clearData.count > zippedSize else {
                XCTFail("Zipped size should be smaller.")
                return
            }
            
            let uzipperData = try zippedData.gunzipped()
            
            guard uzipperData.count == clearData.count else {
                XCTFail("Zipped size should be equal unzipped.")
                return
            }
            
            let unzippedValue = String(data: uzipperData, encoding: .utf8)
            
            guard value == unzippedValue else {
                XCTFail("Unzipped value should be equal value.")
                return
            }
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    static var allTests = [
        ("testZipUZip", testZipUZip),
    ]
}
