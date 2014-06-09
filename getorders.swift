#!/usr/bin/xcrun swift -i

//
//  GetOrdersSwift
//
//  Created by Duane Moore on 6/8/14.
//  Copyright (c) 2014 Duane Moore. All rights reserved.
//

import Foundation

var token = ""
var merchantId = ""
let processInfo = NSProcessInfo()
let env = processInfo.environment
if let cloverTokenEnv : AnyObject = env["CLOVER_TOKEN"] {
    token = cloverTokenEnv as String
}
var baseUrl = "http://localhost:9001"

// constants to access data from JSON response
let ELEMENTS = "elements"
let MERCHANT_ID = "id"
let MERCHANT_LOCALE = "locale"
let MERCHANT_CURRENCY = "defaultCurrency"
let ORDER_STATE = "state"
let ORDER_STATE_LOCKED = "locked"
let ORDER_ID = "id"
let ORDER_TOTAL = "total"
let ORDER_LINE_ITEMS = "lineItems"
let LINE_ITEM_NAME = "name"
let LINE_ITEM_PRICE = "price"

var taskComplete = false
var jsonError: NSError?
let header = ["Authorization" : "Bearer \(token)"]
let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

func loadOrders(currencyFormatter: NSNumberFormatter, cents: Double) {
    let orderUrl = NSURL(string: "\(baseUrl)/v3/merchants/\(merchantId)/orders?expand=lineItems")
    let orderRequest = NSMutableURLRequest(URL: orderUrl)
    orderRequest.allHTTPHeaderFields = header
    let orderHandler = {
        (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
        // to dump entire response, uncomment the following:
        //var jsonDump = NSString(data: data, encoding: NSUTF8StringEncoding) // TODO: read encoding from http response
        //println(jsonDump)

        let jsonData: AnyObject! = NSJSONSerialization.JSONObjectWithData(data,
            options: NSJSONReadingOptions(0), error: &jsonError)
        if jsonData {
            println(jsonData)
            let jsonDictionary: Dictionary<String, AnyObject> = jsonData as Dictionary<String, AnyObject>
            let orders:AnyObject? = jsonDictionary[ELEMENTS]
            let ordersArray:Array<Dictionary<String, AnyObject>> = orders as Array<Dictionary<String, AnyObject>>
            for order in ordersArray {
                let orderStateObj:AnyObject? = order[ORDER_STATE]
                if let orderState = orderStateObj as? String {
                    if orderState == ORDER_STATE_LOCKED { // only show completed orders
                        let orderUuidObj:AnyObject? = order[ORDER_ID]
                        let orderPriceObj:AnyObject? = order[ORDER_TOTAL]
                        if let orderUuid = orderUuidObj as? String {
                            print("order \(orderUuid)")
                        }
                        if let orderPrice = orderPriceObj as? Int {
                            let price = Double(orderPrice) / cents
                            let priceStr = currencyFormatter.stringFromNumber(price)
                            print(", total = \(priceStr)")
                        }
                        println()
                        if let lineItemsObj:AnyObject? = order[ORDER_LINE_ITEMS] {
                            if let lineItemsDict: Dictionary<String, AnyObject> = lineItemsObj as? Dictionary<String, AnyObject> {
                                let lineItems:AnyObject? = lineItemsDict[ELEMENTS]
                                let lineItemsArray:Array<Dictionary<String, AnyObject>> = lineItems as Array<Dictionary<String, AnyObject>>
                                for lineItem in lineItemsArray {
                                    let lineItemNameObj:AnyObject? = lineItem[LINE_ITEM_NAME]
                                    if let lineItemName = lineItemNameObj as? String {
                                        print("\tline item = \(lineItemName)")
                                    }
                                    let lineItemPriceObj:AnyObject? = lineItem[LINE_ITEM_PRICE]
                                    if let lineItemPrice = lineItemPriceObj as? Int {
                                        let price = Double(lineItemPrice) / cents
                                        let priceStr = currencyFormatter.stringFromNumber(price)
                                        print(", price = \(priceStr)")
                                    }
                                    println()
                                }
                            }
                        }
                    }
                }
            }
        }
        taskComplete = true
    }
    session.dataTaskWithRequest(orderRequest, orderHandler).resume()
}

func loadMerchantProperties() {
    let merchantPropertiesUrl = NSURL(string: "\(baseUrl)/v3/merchants/\(merchantId)/properties")
    let merchantPropertiesRequest = NSMutableURLRequest(URL: merchantPropertiesUrl)
    merchantPropertiesRequest.allHTTPHeaderFields = header
    let task = session.dataTaskWithRequest(merchantPropertiesRequest) {
        (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
        let jsonData: AnyObject! = NSJSONSerialization.JSONObjectWithData(data,
            options: NSJSONReadingOptions(0), error: &jsonError)
        if jsonData {
            let jsonDict: Dictionary<String, AnyObject> = jsonData as Dictionary<String, AnyObject>
            let localeIdentifierObj:AnyObject? = jsonDict[MERCHANT_LOCALE]
            let currencyCodeObj:AnyObject? = jsonDict[MERCHANT_CURRENCY]
            let localeIdentifier = localeIdentifierObj as? String
            let currencyCode = currencyCodeObj as? String
            let currencyDict = NSDictionary(object: NSLocaleCurrencyCode, forKey: currencyCode)
            let locale = NSLocale(localeIdentifier: localeIdentifier)
            let currencyFormatter = NSNumberFormatter()
            currencyFormatter.locale = locale
            currencyFormatter.currencyCode = currencyCode
            currencyFormatter.numberStyle = .CurrencyStyle
            let fractionDigits:NSNumber = currencyFormatter.maximumFractionDigits
            let cents = pow(10, fractionDigits.doubleValue)
            loadOrders(currencyFormatter, cents)
        }
    }
    task.resume()
}

func loadMerchantInfo() {
    let merchantInfoUrl = NSURL(string: "\(baseUrl)/v3/merchants/current")
    let merchantInfoRequest = NSMutableURLRequest(URL: merchantInfoUrl)
    merchantInfoRequest.allHTTPHeaderFields = header
    let task = session.dataTaskWithRequest(merchantInfoRequest) {
        (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
        let jsonData: AnyObject! = NSJSONSerialization.JSONObjectWithData(data,
            options: NSJSONReadingOptions(0), error: &jsonError)
        if jsonData {
            let jsonDict: Dictionary<String, AnyObject> = jsonData as Dictionary<String, AnyObject>
            let idObj:AnyObject? = jsonDict[MERCHANT_ID]
            if let mid = idObj as? String {
                merchantId = mid
                loadMerchantProperties()
            }
        }
    }
    task.resume()
}

loadMerchantInfo()

while (!taskComplete) {
    if !NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture() as NSDate) {
        break
    }
}
println("done...")

