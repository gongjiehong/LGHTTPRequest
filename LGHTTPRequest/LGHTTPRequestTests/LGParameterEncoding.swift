//
//  LGParameterEncoding.swift
//  LGHTTPRequestTests
//
//  Created by 龚杰洪 on 2018/1/8.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import XCTest
import LGHTTPRequest
class LGParameterEncoding: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testXOREncode() {
        let appid = "D968E05BB47588EFB592616C133D05A0"
        let appkey = "A753E91255788246E0CE7180BF240F9B"
        
        let encoder = LGJsonXOREncoding(publicKey: appid, privateKey: appkey)
        let request = URLRequest(url: URL(string: "http://www.cxylg.com")!)
        do {
            let _ = try encoder.encode(request, with: ["123": "中文123456789123456789123456789"])
        } catch {
            
        }
    }
    
}
