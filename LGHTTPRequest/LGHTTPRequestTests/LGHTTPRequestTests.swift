//
//  LGHTTPRequestTests.swift
//  LGHTTPRequestTests
//
//  Created by 龚杰洪 on 2017/11/21.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import XCTest
import LGHTTPRequest

public let kEncryptAppID = "7558D6A77DE4B2220396796EFC2F1D96"
public let kEncryptAppKey = "4C812EDDFE988D03917D0D27FE130AD3"
public let kServiceHost = "http://192.168.1.123:3000/mobile/publicOauthService.php"
public let kInterfaceVersion = "V370"
public let kClientBundleVersion = "3.7.1"

//public let kServiceHost = "http://192.168.1.123:3000/mobile/publicOauthService.php"
//public let kInterfaceVersion = "V380"
//public let kClientBundleVersion = "3.8.0"

class LGHTTPRequestTests: XCTestCase {
    
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
}


