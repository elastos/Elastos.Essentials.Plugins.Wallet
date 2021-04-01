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

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>
#include "json.hpp"
#import <string.h>
#import <map>

typedef std::string String;
typedef nlohmann::json Json;

class WalletHttprequest
{
public:
    WalletHttprequest(String &ethscRPC, String &ethscApiMisc);
    WalletHttprequest(String &ethscGetTokenList);
    ~WalletHttprequest();

    NSString * getRequest(NSString *urlStr);
    nlohmann::json postRequest(NSString *body);

    nlohmann::json GasPrice(int id);
    nlohmann::json EstimateGas(const std::string &from, const std::string &to, const std::string &amount,
            const std::string &gasPrice, const std::string &data, int id);
    nlohmann::json GetBalance(const std::string &address, int id);
    nlohmann::json SubmitTransaction(const std::string &tx, int id);
    nlohmann::json GetTransactions(const std::string &address, uint64_t begBlockNumber, uint64_t endBlockNumber, int id);
    nlohmann::json GetLogs(const std::string &contract, const std::string &address, const std::string &event, uint64_t begBlockNumber, uint64_t endBlockNumber, int id);
    nlohmann::json GetTokens(int id);
    nlohmann::json GetBlockNumber(int id);
    nlohmann::json GetNonce(const std::string &address, int id);

    NSString* GetTokenListByAddress(const std::string &address);

private:
    void transformDict(NSMutableDictionary *dictM, NSString *originKey, NSString *newkey);

    NSString * mEthscRPC;
    NSString * mEthscApiMisc;
    NSString * mEthscGetTokenList;
    NSString * mGetTransactionsUrlPrefix;
    NSString * mGetTokensUrlPrefix;
    NSString * mGetTokenListUrlPrefix;
};
