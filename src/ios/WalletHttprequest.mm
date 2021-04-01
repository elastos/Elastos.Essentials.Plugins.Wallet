/*
 * Copyright (c) 2021 Elastos Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "WalletHttprequest.h"
#import <Cordova/CDVCommandDelegate.h>

#pragma mark - WalletHttprequest C++

//using namespace Elastos::ElaWallet;

WalletHttprequest::WalletHttprequest(String &ethscRPC,
                                    String &ethscApiMisc)
{
    mEthscRPC = [NSString stringWithCString:ethscRPC.c_str() encoding:NSUTF8StringEncoding];
    mEthscApiMisc = [NSString stringWithCString:ethscApiMisc.c_str() encoding:NSUTF8StringEncoding];

    mGetTransactionsUrlPrefix = [mEthscApiMisc stringByAppendingString:@"/api/1/eth/history?address="];
    mGetTokensUrlPrefix = [mEthscApiMisc stringByAppendingString:@"/api/1/eth/erc20/list"];
}

WalletHttprequest::WalletHttprequest(String &ethscGetTokenList)
{
    mEthscGetTokenList = [NSString stringWithCString:ethscGetTokenList.c_str() encoding:NSUTF8StringEncoding];

    mGetTokenListUrlPrefix = [mEthscGetTokenList stringByAppendingString:@"/api/?module=account&action=tokenlist&address="];
}

WalletHttprequest::~WalletHttprequest()
{
}

nlohmann::json WalletHttprequest::GasPrice(int id)
{
    NSString *body = [NSString stringWithFormat:@"{  \"method\": \"eth_gasPrice\", \"id\":%d}", id];
    return postRequest(body);
}

nlohmann::json WalletHttprequest::EstimateGas(const std::string &from, const std::string &to, const std::string &amount,
            const std::string &gasPrice, const std::string &data, int id)
{
    NSString *body = [NSString stringWithFormat:@"{  \"method\": \"eth_estimateGas\", \"params\": [{\"from\": \"%s\", \"to\": \"%s\", \"amount\": \"%s\", \"gasPrice\": \"%s\", \"data\": \"%s\"}], \"id\":%d}", from.c_str(), to.c_str(), amount.c_str(), gasPrice.c_str(), data.c_str(), id];
    return postRequest(body);
}

nlohmann::json WalletHttprequest::GetBalance(const std::string &address, int id)
{
    NSString *body = [NSString stringWithFormat:@"{  \"method\": \"eth_getBalance\", \"params\": [\"%s\", \"latest\"], \"id\":%d}", address.c_str(), id];
    return postRequest(body);
}

nlohmann::json WalletHttprequest::SubmitTransaction(const std::string &tx, int id)
{
    NSString *body = [NSString stringWithFormat:@"{  \"method\": \"eth_sendRawTransaction\", \"params\": [\"%s\"], \"id\":%d}", tx.c_str(), id];
    return postRequest(body);
}

nlohmann::json WalletHttprequest::GetTransactions(const std::string &address, uint64_t begBlockNumber, uint64_t endBlockNumber, int id)
{
    NSString *addressNSString = [NSString stringWithCString:address.c_str() encoding:NSUTF8StringEncoding];
    NSString *urlStr = [mGetTransactionsUrlPrefix stringByAppendingString:addressNSString];
    NSString* jsonString = getRequest(urlStr);
    if (jsonString == nil) {
        return "{}";
    }

    NSError *err;
    NSMutableDictionary *dictMutable = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&err];
    if (dictMutable == nil) {
        return "{}";
    }

    [dictMutable setValue:@(id) forKey:@"id"];

    // transform data for spvsdk
    NSArray * arrayTmp = [dictMutable objectForKey:@"result"];
    if (arrayTmp != nil) {
        unsigned long arrayLen = arrayTmp.count;
        for (int i = 0; i < arrayLen; i++) {
            NSMutableDictionary* transactionMutable = arrayTmp[i];

            transformDict(transactionMutable, @"contractAddress", @"contract");
            transformDict(transactionMutable, @"value", @"amount");
            transformDict(transactionMutable, @"input", @"data");
            transformDict(transactionMutable, @"confirmations", @"blockConfirmations");
            transformDict(transactionMutable, @"transactionIndex", @"blockTransactionIndex");
            transformDict(transactionMutable, @"timeStamp", @"blockTimestamp");
            [transactionMutable setValue:@"5012644" forKey:@"gasLimit"];
        }
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:dictMutable options:kNilOptions error:nil];
    if (data == nil) {
        return "{}";
    }

    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return nlohmann::json::parse([string UTF8String]);
}

nlohmann::json WalletHttprequest::GetLogs(const std::string &contract, const std::string &address, const std::string &event, uint64_t begBlockNumber, uint64_t endBlockNumber, int id)
{
    NSString *body = [NSString stringWithFormat:@"{  \"method\": \"eth_getLogs\", \"params\": [{\"topics\": [\"%s\", null, \"%s\"], \"fromBlock\": \"0x%llx\", \"toBlock\": \"0x%llx\"}], \"id\":%d}", event.c_str(), address.c_str(), begBlockNumber, endBlockNumber, id];
    return postRequest(body);
}

nlohmann::json WalletHttprequest::GetTokens(int id)
{
    NSString* jsonString = getRequest(mGetTokensUrlPrefix);
    if (jsonString == nil) {
        return "{}";
    }

    NSError *err;
    NSMutableDictionary *dictMutable = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&err];
    if (dictMutable == nil) {
        return "{}";
    }
    [dictMutable setValue:@(id) forKey:@"id"];

    // TODO: if the spvsdk use string for decimals, then remove this code.
    NSArray * arrayTmp = [dictMutable objectForKey:@"result"];
    if (arrayTmp != nil) {
        unsigned long arrayLen = arrayTmp.count;
        for (int i = 0; i < arrayLen; i++) {
            NSMutableDictionary* transactionMutable = arrayTmp[i];

            try {
                NSString *text = [transactionMutable objectForKey:@"decimals"];
                int intString = [text intValue];
                [transactionMutable setValue:@(intString) forKey:@"decimals"];
            } catch (const std:: exception & e ) {
                NSString *errString = [NSString stringWithCString:e.what() encoding:NSUTF8StringEncoding];
                NSLog(@"WalletHttprequest::transformDict error: %@", errString);
            }
        }
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:dictMutable options:kNilOptions error:nil];
    if (data == nil) {
        return "{}";
    }

    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return nlohmann::json::parse([string UTF8String]);
}

nlohmann::json WalletHttprequest::GetBlockNumber(int id)
{
    NSString *body = [NSString stringWithFormat:@"{  \"method\": \"eth_blockNumber\", \"id\":%d}", id];
    return postRequest(body);
}

nlohmann::json WalletHttprequest::GetNonce(const std::string &address, int id)
{
    NSString *body = [NSString stringWithFormat:@"{  \"method\": \"eth_getTransactionCount\", \"params\": [\"%s\", \"latest\"], \"id\":%d}", address.c_str(), id];
    return postRequest(body);
}

NSString* WalletHttprequest::GetTokenListByAddress(const std::string &address)
{
    NSString *addressNSString = [NSString stringWithCString:address.c_str() encoding:NSUTF8StringEncoding];
    NSString *urlStr = [mGetTokenListUrlPrefix stringByAppendingString:addressNSString];
    NSString* jsonString = getRequest(urlStr);
    if (jsonString == nil) {
        return @"{}";
    }

    return jsonString;
}

NSString * WalletHttprequest::getRequest(NSString *urlStr)
{
    NSURL *url = [[NSURL alloc] initWithString:urlStr];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];

    NSDictionary *headers = [request allHTTPHeaderFields];
    [headers setValue:@"iOS-Client-ABC" forKey:@"User-Agent"];

    [request setHTTPMethod:@"GET"];

    NSURLResponse *response;
    NSError *error;
    NSString *resultString = nil;

    try {
        NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSInteger statusCode = [httpResponse statusCode];
        if (statusCode == 200) {
            resultString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
        } else {
            NSString *errorDesc = [error localizedDescription];
            NSLog(@"WalletHttprequest::getRequest error : %@\n", errorDesc);
        }
    } catch (const std:: exception & e ) {
        NSString *errString = [NSString stringWithCString:e.what() encoding:NSUTF8StringEncoding];
        NSLog(@"WalletHttprequest::getRequest error: %@", errString);
    }

    return resultString;
}

nlohmann::json WalletHttprequest::postRequest(NSString *body)
{
    // NSLog(@" ----WalletHttprequest::postRequest body:%@\n", body);

    NSURL *url = [[NSURL alloc] initWithString:mEthscRPC];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];

    NSDictionary *headers = [request allHTTPHeaderFields];
    [headers setValue:@"iOS-Client-ABC" forKey:@"User-Agent"];

    request.HTTPMethod = @"post";

    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setValue:@"application/json" forKey:@"Content-Type"];
    [request setAllHTTPHeaderFields:dic];

    NSMutableData *postBody = [NSMutableData data];
    [postBody appendData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:postBody];

    NSURLResponse *response;
    NSError *error;
    NSString *resultString = @"{}";

    try {
        NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSInteger statusCode = [httpResponse statusCode];

        if (statusCode == 200) {
            resultString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
        } else {
            NSString *errorDesc = [error localizedDescription];
            NSLog(@"WalletHttprequest::postrequest error : %@\n", errorDesc);
        }
    } catch (const std:: exception & e ) {
        NSString *errString = [NSString stringWithCString:e.what() encoding:NSUTF8StringEncoding];
        NSLog(@"WalletHttprequest::postRequest error: %@", errString);
    }

    return nlohmann::json::parse([resultString UTF8String]);
}

void WalletHttprequest::transformDict(NSMutableDictionary *dictM, NSString *originKey, NSString *newkey) {
    try {
        NSString *text = [dictM objectForKey:originKey];
        [dictM setValue:text forKey:newkey];
        [dictM removeObjectForKey:originKey];
    } catch (const std:: exception & e ) {
        NSString *errString = [NSString stringWithCString:e.what() encoding:NSUTF8StringEncoding];
        NSLog(@"WalletHttprequest::transformDict originKey: %@, error: %@", originKey, errString);
    }
}
