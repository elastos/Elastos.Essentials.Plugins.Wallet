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

#import "Wallet.h"
#import "WalletHttprequest.h"
#import <Cordova/CDVCommandDelegate.h>
#import "WrapSwift.h"

#pragma mark - ElISubWalletCallback C++

using namespace Elastos::ElaWallet;
class ElISubWalletCallback: public ISubWalletCallback
{
public:
    ElISubWalletCallback(String &masterWalletID, String &chainID, String &ethscRPC, String &ethscApiMisc, NSMutableDictionary *commandDict);

    ~ElISubWalletCallback();

    void SendPluginResult(NSDictionary* dict);

    CDVPluginResult *successAsDict(NSDictionary* dict);
    CDVPluginResult *successAsString(NSString* str);
    CDVPluginResult *errorProcess(int code, id msg);

    void OnTransactionStatusChanged(const std::string &txid, const std::string &status, const nlohmann::json &desc, uint32_t confirms);
    void OnBalanceChanged(const std::string &asset, const std::string & balance);
    void OnBlockSyncProgress(const nlohmann::json &progressInfo);
    void OnTxPublished(const std::string &hash, const nlohmann::json &result);
    void OnAssetRegistered(const std::string &asset, const nlohmann::json &info);
    void OnConnectStatusChanged(const std::string &status);
    void OnETHSCEventHandled(const nlohmann::json &event);

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


private:
    NSString * mMasterWalletID;
    NSString * mSubWalletID;
    NSMutableDictionary *mCommandDict;
    WalletHttprequest *mHttprequest;

    NSString *keySuccess;//   = @"success";
    NSString *keyError;//     = "error";
    NSString *keyCode;//      = "code";
    NSString *keyMessage;//   = "message";
    NSString *keyException;// = "exception";
};

ElISubWalletCallback::ElISubWalletCallback(String &masterWalletID,
                                           String &chainID, String &ethscRPC, String &ethscApiMisc, NSMutableDictionary *commandDict)
{
    mMasterWalletID = [NSString stringWithCString:masterWalletID.c_str() encoding:NSUTF8StringEncoding];
    mSubWalletID = [NSString stringWithCString:chainID.c_str() encoding:NSUTF8StringEncoding];
    mCommandDict = commandDict;

    mHttprequest = new WalletHttprequest(ethscRPC, ethscApiMisc);

    keySuccess   = @"success";
    keyError     = @"error";
    keyCode      = @"code";
    keyMessage   = @"message";
    keyException = @"exception";
}

ElISubWalletCallback::~ElISubWalletCallback()
{
}

CDVPluginResult *ElISubWalletCallback::successAsDict(NSDictionary* dict)
{
    [dict setValue:mMasterWalletID forKey:@"MasterWalletID"];
    [dict setValue:mSubWalletID forKey:@"ChainID"];

    CDVPluginResult* pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    pluginResult.keepCallback = [NSNumber numberWithBool:YES];
    return pluginResult;
}

CDVPluginResult *ElISubWalletCallback::successAsString(NSString* str)
{
    CDVPluginResult* pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:str];
    pluginResult.keepCallback = [NSNumber numberWithBool:YES];
    return pluginResult;
}

CDVPluginResult *ElISubWalletCallback::errorProcess(int code, id msg)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setValue:[NSNumber numberWithInt:code] forKey:keyCode];
    [dict setValue:msg forKey:keyMessage];

    CDVPluginResult* pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary: dict];
    pluginResult.keepCallback = [NSNumber numberWithBool:YES];
    return pluginResult;
}

void ElISubWalletCallback::OnTransactionStatusChanged(const std::string &txid,
                        const std::string &status, const nlohmann::json &desc, uint32_t confirms)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSString *txIdStr = [NSString stringWithCString:txid.c_str() encoding:NSUTF8StringEncoding];
    NSString *statusStr = [NSString stringWithCString:status.c_str() encoding:NSUTF8StringEncoding];
    NSString *descStr = [NSString stringWithCString:desc.dump().c_str() encoding:NSUTF8StringEncoding];
    NSNumber *confirmNum = [NSNumber numberWithInt:confirms];

    [dict setValue:txIdStr forKey:@"txId"];
    [dict setValue:statusStr forKey:@"status"];
    [dict setValue:descStr forKey:@"desc"];
    [dict setValue:confirmNum forKey:@"confirms"];
    [dict setValue:@"OnTransactionStatusChanged" forKey:@"Action"];

    SendPluginResult(dict);
}

void ElISubWalletCallback::OnBlockSyncProgress(const nlohmann::json &progressInfo)
{
    NSString *progressInfoString = [NSString stringWithCString:progressInfo.dump().c_str() encoding:NSUTF8StringEncoding];

    NSError *err;
    NSMutableDictionary *dict = [NSJSONSerialization JSONObjectWithData:[progressInfoString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&err];
    [dict setValue:@"OnBlockSyncProgress" forKey:@"Action"];

    SendPluginResult(dict);
}

void ElISubWalletCallback::OnBalanceChanged(const std::string &asset, const std::string &balance)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    NSString *assetString = [NSString stringWithCString:asset.c_str() encoding:NSUTF8StringEncoding];
    NSString *balanceString = [NSString stringWithCString:balance.c_str() encoding:NSUTF8StringEncoding];

    [dict setValue:assetString forKey:@"Asset"];
    [dict setValue:balanceString forKey:@"Balance"];
    [dict setValue:@"OnBalanceChanged" forKey:@"Action"];

    SendPluginResult(dict);
}

void ElISubWalletCallback::OnTxPublished(const std::string &hash, const nlohmann::json &result)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    NSString *hashString = [NSString stringWithCString:hash.c_str() encoding:NSUTF8StringEncoding];
    NSString *resultString = [NSString stringWithCString:result.dump().c_str() encoding:NSUTF8StringEncoding];

    [dict setValue:hashString forKey:@"hash"];
    [dict setValue:resultString forKey:@"result"];
    [dict setValue:@"OnTxPublished" forKey:@"Action"];

    SendPluginResult(dict);
}

void ElISubWalletCallback::OnAssetRegistered(const std::string &asset, const nlohmann::json &info)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    NSString *assetString = [NSString stringWithCString:asset.c_str() encoding:NSUTF8StringEncoding];
    NSString *infoString = [NSString stringWithCString:info.dump().c_str() encoding:NSUTF8StringEncoding];

    [dict setValue:assetString forKey:@"asset"];
    [dict setValue:infoString forKey:@"info"];
    [dict setValue:@"OnAssetRegistered" forKey:@"Action"];

    SendPluginResult(dict);
}

void ElISubWalletCallback::OnConnectStatusChanged(const std::string &status)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSString *statusString = [NSString stringWithCString:status.c_str() encoding:NSUTF8StringEncoding];

    [dict setValue:statusString forKey:@"status"];
    [dict setValue:@"OnConnectStatusChanged" forKey:@"Action"];

    SendPluginResult(dict);
}

void ElISubWalletCallback::OnETHSCEventHandled(const nlohmann::json &event)
{
    NSError *err;
    NSString *eventInfoString = [NSString stringWithCString:event.dump().c_str() encoding:NSUTF8StringEncoding];
    NSMutableDictionary *eventDict = [NSJSONSerialization JSONObjectWithData:[eventInfoString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&err];

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setValue:eventDict forKey:@"event"];
    [dict setValue:@"OnETHSCEventHandled" forKey:@"Action"];

    SendPluginResult(dict);
}

nlohmann::json ElISubWalletCallback::GasPrice(int id)
{
    return mHttprequest->GasPrice(id);
}

nlohmann::json ElISubWalletCallback::EstimateGas(const std::string &from, const std::string &to, const std::string &amount,
            const std::string &gasPrice, const std::string &data, int id)
{
    return mHttprequest->EstimateGas(from, to, amount, gasPrice, data, id);
}

nlohmann::json ElISubWalletCallback::GetBalance(const std::string &address, int id)
{
    return mHttprequest->GetBalance(address, id);
}

nlohmann::json ElISubWalletCallback::SubmitTransaction(const std::string &tx, int id)
{
    return mHttprequest->SubmitTransaction(tx, id);
}

nlohmann::json ElISubWalletCallback::GetTransactions(const std::string &address, uint64_t begBlockNumber, uint64_t endBlockNumber, int id)
{
    return mHttprequest->GetTransactions(address, begBlockNumber, endBlockNumber, id);
}

nlohmann::json ElISubWalletCallback::GetLogs(const std::string &contract, const std::string &address, const std::string &event, uint64_t begBlockNumber, uint64_t endBlockNumber, int id)
{
    return mHttprequest->GetLogs(contract, address, event, begBlockNumber, endBlockNumber, id);
}

nlohmann::json ElISubWalletCallback::GetTokens(int id)
{
    return mHttprequest->GetTokens(id);
}

nlohmann::json ElISubWalletCallback::GetBlockNumber(int id)
{
    return mHttprequest->GetBlockNumber(id);
}

nlohmann::json ElISubWalletCallback::GetNonce(const std::string &address, int id)
{
    return mHttprequest->GetNonce(address, id);
}

void ElISubWalletCallback::SendPluginResult(NSDictionary* dict)
{
    CDVPluginResult* pluginResult = nil;
    pluginResult = successAsDict(dict);

    for (id key in subwalletListenerMDict) {
        NSMutableDictionary *commandDict = [subwalletListenerMDict objectForKey:key];
        CDVInvokedUrlCommand* command = [commandDict objectForKey:@"command"];
        id <CDVCommandDelegate> commandDelegate = [commandDict objectForKey:@"commandDelegate"];
        [commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

#pragma mark - Wallet

@interface Wallet ()
{
}

@end


@implementation Wallet

#pragma mark -
- (IMasterWallet *)getIMasterWallet:(String)masterWalletID
{
    if (mMasterWalletManager == nil) {
        return nil;
    }
    return mMasterWalletManager->GetMasterWallet(masterWalletID);
}

- (ISubWallet *)getSubWallet:(String)masterWalletID :(String)chainID
{
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        return nil;
    }
    ISubWalletVector subWalletList = masterWallet->GetAllSubWallets();
    for (int i = 0; i < subWalletList.size(); i++) {
        ISubWallet *iSubWallet = subWalletList[i];
        NSString *getChainIDString = [self stringWithCString:iSubWallet->GetChainID()];
        NSString *chainIDString = [self stringWithCString:chainID];

        if ([chainIDString isEqualToString:getChainIDString]) {
            return iSubWallet;
        }
    }
    return nil;
}

#pragma mark -

- (NSString *)getBasicInfo:(IMasterWallet *)masterWallet
{
    Json json = masterWallet->GetBasicInfo();
    NSString *jsonString = [self stringWithCString:json.dump()];
    return jsonString;
}

- (NSString *)formatWalletName:(String)stdStr
{
    NSString *string = [self stringWithCString:stdStr];
    NSString *str = [NSString stringWithFormat:@"(%@)", string];
    return str;
}
- (NSString *)formatWalletNameWithString:(String)stdStr other:(String)other
{
    NSString *string = [self stringWithCString:stdStr];
    NSString *otherString = [self stringWithCString:other];
    NSString *str = [NSString stringWithFormat:@"(%@:%@)", string, otherString];
    return str;
}

- (void)errCodeInvalidArg:(CDVInvokedUrlCommand *)command code:(int)code idx:(int)idx
{
    NSString *msg = [NSString stringWithFormat:@"%d %@", idx, @" parameters are expected"];
    return [self errorProcess:command code:code msg:msg];
}

- (void)successAsDict:(CDVInvokedUrlCommand *)command  msg:(NSDictionary*) dict
{
    CDVPluginResult*  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)successAsArray:(CDVInvokedUrlCommand *)command  msg:(NSArray*) array
{
    CDVPluginResult*  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)successAsString:(CDVInvokedUrlCommand *)command  msg:(NSString*) msg
{
    CDVPluginResult*  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:msg];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)errorProcess:(CDVInvokedUrlCommand *)command  code : (int) code msg:(id) msg
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setValue:[NSNumber numberWithInt:code] forKey:keyCode];
    [dict setValue:msg forKey:keyMessage];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dict];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)exceptionProcess:(CDVInvokedUrlCommand *)command  string:(String) exceptionString
{
    NSString *errString=[self stringWithCString:exceptionString];
    NSDictionary *dic=  [self dictionaryWithJsonString:errString];
    if (dic != nil) {
        [self errorProcess:command code:[dic[@"Code"] intValue] msg:dic[@"Message"]];
    } else {
        // if the exceptionString isn't json string
        [self errorProcess:command code:errCodeWalletException msg:errString];
    }
}

- (NSDictionary *)parseOneParam:(NSString *)key value:(NSString *)value
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setValue:value forKey:key];
    return dict;
}

- (NSString *)dictToJSONString:(NSDictionary *)dict
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict
                                        options:kNilOptions
                                        error:nil];
    if (data == nil) {
        return nil;
    }

    NSString *string = [[NSString alloc] initWithData:data
                                          encoding:NSUTF8StringEncoding];
    return string;
}

- (NSString *)arrayToJSONString:(NSArray *)array
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:array
                                        options:NSJSONReadingMutableLeaves | NSJSONReadingAllowFragments
                                        error:nil];
    if (data == nil) {
        return nil;
    }

    NSString *string = [[NSString alloc] initWithData:data
                                            encoding:NSUTF8StringEncoding];
    return string;
}
#pragma mark - String Json NSString

- (Json)jsonWithString:(NSString *)string
{
    String std = [self cstringWithString:string];
    Json json = Json::parse(std);
    return json;
}

- (Json)jsonWithDict:(NSDictionary *)dict
{
    NSString *string = [self dictToJSONString:dict];
    String std = [self cstringWithString:string];
    Json json = Json::parse(std);
    return json;
}

- (String)stringWithDict:(NSDictionary *)dict
{
    NSString *string = [self dictToJSONString:dict];
    String std = [self cstringWithString:string];
    return std;
}

- (NSString *)stringWithJson:(Json)json
{
    return [self stringWithCString:json.dump()];
}
//String 转 NSString
- (NSString *)stringWithCString:(String)string
{
    NSString *str = [NSString stringWithCString:string.c_str() encoding:NSUTF8StringEncoding];
    NSString *beginStr = [str substringWithRange:NSMakeRange(0, 1)];

    NSString *result = str;
    if([beginStr isEqualToString:@"\""])
    {
        result = [str substringWithRange:NSMakeRange(1, str.length - 1)];
    }
    NSString *endStr = [result substringWithRange:NSMakeRange(result.length - 1, 1)];
    if([endStr isEqualToString:@"\""])
    {
        result = [result substringWithRange:NSMakeRange(0, result.length - 1)];
    }
    return result;
}

- (String)cstringWithString:(NSString *)string
{
    String  str = [string UTF8String];
    return str;
}

-(NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) {
        return nil;
    }
    NSData *jsonData = [[jsonString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\\r\\n"] dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                            options:NSJSONReadingMutableContainers
                                            error:&err];
    if(err) {
        return nil;
    }
    return dic;
}

#pragma mark - plugin

- (void)applicationEnterBackground
{
}
- (void)applicationBecomeActive
{
}

- (void)pluginInitialize
{
    // app启动或者app从后台进入前台都会调用这个方法
    //    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    // app从后台进入前台都会调用这个方法
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBecomeActive) name:UIApplicationWillEnterForegroundNotification object:nil];
    // 添加检测app进入后台的观察者
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationEnterBackground) name: UIApplicationDidEnterBackgroundNotification object:nil];

    //    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ApplicationWillTerminateNotification) name: UIApplicationWillTerminateNotification object:nil];


    //    ISubWalletVector = new  ISubWalletVector();
    //    ISubWalletArray = [[NSMutableArray alloc] init];
    //    ISubWalletCallBackArray = [[NSMutableArray alloc] init];
    //
    TAG = @"Wallet";

    walletRefCount++;

    keySuccess   = @"success";
    keyError     = @"error";
    keyCode      = @"code";
    keyMessage   = @"message";
    keyException = @"exception";

    errCodeParseJsonInAction          = 10000;
    errCodeInvalidArg                 = 10001;
    errCodeInvalidMasterWallet        = 10002;
    errCodeInvalidSubWallet           = 10003;
    errCodeCreateMasterWallet         = 10004;
    errCodeCreateSubWallet            = 10005;
    errCodeRecoverSubWallet           = 10006;
    errCodeInvalidMasterWalletManager = 10007;
    errCodeImportFromKeyStore         = 10008;
    errCodeImportFromMnemonic         = 10009;
    errCodeSubWalletInstance          = 10010;
    errCodeActionNotFound             = 10013;
    errCodeGetAllMasterWallets        = 10014;

    errCodeWalletException            = 20000;

    if (nil != mMasterWalletManager) {
        return;
    }

    // NSString* rootPath = [NSHomeDirectory() stringByAppendingString:@"/Documents/spv"];
    NSString* rootPath = [[self getDataPath] stringByAppendingString:@"spv"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:rootPath]) {
        [fm createDirectoryAtPath:rootPath withIntermediateDirectories:true attributes:NULL error:NULL];
    }

    NSString* dataPath = [rootPath stringByAppendingString:@"/data"];
    if (![fm fileExistsAtPath:dataPath]) {
        [fm createDirectoryAtPath:dataPath withIntermediateDirectories:true attributes:NULL error:NULL];
    }
    netType = [WrapSwift getNetworkType];
    NSString* config = [WrapSwift getNetworkConfig];

    mEthscjsonrpcUrl = [self cstringWithString:[WrapSwift getPreferenceStringValue:@"sidechain.eth.rpcapi" :@""]];
    mEthscapimiscUrl = [self cstringWithString:[WrapSwift getPreferenceStringValue:@"sidechain.eth.apimisc" :@""]];
    if ([netType isEqual: @"TestNet"]) {
        mEthscGetTokenListUrl = "https://eth-testnet.elastos.io";
    } else {
        mEthscGetTokenListUrl = "https://eth.elastos.io";
    }

    try {
        NSLog(@"WALLETTEST new MasterWalletManager rootPath: %@,  dataPath:%@", rootPath, dataPath);
        mMasterWalletManager = new MasterWalletManager([rootPath UTF8String], [netType UTF8String],
                [config UTF8String], [dataPath UTF8String]);
       mMasterWalletManager->SetLogLevel("warning");
    } catch (const std:: exception & e ) {
        NSString *errString=[self stringWithCString:e.what()];
        NSLog(@"new MasterWalletManager error: %@", errString);
    }

    currentDid = [self did];

    [self addWalletListener];

    walletSemaphore = dispatch_semaphore_create(1);

    [super pluginInitialize];
}


- (void)dispose
{
    walletRefCount--;

    if (mMasterWalletManager != nil) {
        NSString *key = [NSString stringWithFormat:@"(%@:%@)", [self did], [self getModeId]];
        [subwalletListenerMDict removeObjectForKey:key];

        if (0 == walletRefCount) {
            try {
                dispatch_semaphore_wait(walletSemaphore, DISPATCH_TIME_FOREVER);

                IMasterWalletVector masterWallets = mMasterWalletManager->GetAllMasterWallets();

                for (int i = 0; i < masterWallets.size(); i++) {
                    IMasterWallet *masterWallet = masterWallets[i];
                    String masterWalletID = masterWallet->GetID();

                    ISubWalletVector subWallets = masterWallet->GetAllSubWallets();
                    for (int j = 0; j < subWallets.size(); j++) {
                        String chainID = subWallets[j]->GetChainID();
                        ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
                        if (subWallet != nil) {
                            try {
                                subWallet->SyncStop();
                                subWallet->RemoveCallback();
                            } catch (const std:: exception &e) {
                                NSLog(@"subWallet SyncStop error: %s", e.what());
                            }
                        }
                    }
                }

                [subwalletListenerMDict removeAllObjects];
                // TODO: crash in spvsdk sometimes
//                delete mMasterWalletManager;
                mMasterWalletManager = nil;
            } catch (const std:: exception &e) {
                NSLog(@"wallet plugin dispose error: %s", e.what());
            }

            dispatch_semaphore_signal(walletSemaphore);
        }
    }

    [super dispose];
}

- (void)coolMethod:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* echo = [command.arguments objectAtIndex:0];

    if (echo != nil && [echo length] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:echo];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)print:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *text = [command.arguments objectAtIndex:0];

    if(!text || ![text isEqualToString:@""]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[self parseOneParam:@"text" value:text]];
    }
    else {
        NSString *error = @"Text not can be null";
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)addWalletListener
{
    try {
        IMasterWalletVector masterWallets = mMasterWalletManager->GetAllMasterWallets();

        for (int i = 0; i < masterWallets.size(); i++) {
            IMasterWallet *masterWallet = masterWallets[i];
            String masterWalletID = masterWallet->GetID();

            ISubWalletVector subWallets = masterWallet->GetAllSubWallets();
            for (int j = 0; j < subWallets.size(); j++) {
                String chainID = subWallets[j]->GetChainID();
                [self addSubWalletListener:masterWalletID chainID:chainID];
            }
        }
    } catch (const std:: exception &e) {
        NSLog(@"addWalletListener error: %s", e.what());
    }
}

- (void)addSubWalletListener:(String)masterWalletID chainID:(String)chainID
{
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        NSLog(@"addSubWalletListener error: %@", msg);
        return;
    }

    ElISubWalletCallback *subCallback =  new ElISubWalletCallback(masterWalletID, chainID, mEthscjsonrpcUrl, mEthscapimiscUrl, subwalletListenerMDict);
    subWallet->AddCallback(subCallback);
}

- (void)getAllMasterWallets:(CDVInvokedUrlCommand *)command
{
    try {
        IMasterWalletVector vector = mMasterWalletManager->GetAllMasterWallets();
        NSMutableArray *masterWalletListJson = [[NSMutableArray alloc] init];
        for (int i = 0; i < vector.size(); i++) {
            IMasterWallet *iMasterWallet = vector[i];
            String idStr = iMasterWallet->GetID();
            NSString *str = [self stringWithCString:idStr];
            [masterWalletListJson addObject:str];
        }
        NSString *jsonString = [self arrayToJSONString:masterWalletListJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createMasterWallet:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *array = command.arguments;

    String masterWalletID = [self cstringWithString:[array objectAtIndex:idx++]];
    String mnemonic       = [self cstringWithString:[array objectAtIndex:idx++]];
    String phrasePassword = [self cstringWithString:[array objectAtIndex:idx++]];
    String payPassword    = [self cstringWithString:[array objectAtIndex:idx++]];
    Boolean singleAddress = [[array objectAtIndex:idx++] boolValue];

    NSArray *args = command.arguments;
    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    try {
        IMasterWallet *masterWallet = mMasterWalletManager->CreateMasterWallet(
                masterWalletID, mnemonic, phrasePassword, payPassword, singleAddress);

        if (masterWallet == NULL) {
            NSString *msg = [NSString stringWithFormat:@"CreateMasterWallet %@", [self formatWalletName:masterWalletID]];
            return [self errorProcess:command code:errCodeCreateMasterWallet msg:msg];
        }

        NSString *jsonString = [self getBasicInfo:masterWallet];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)generateMnemonic:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    NSString *language = args[idx++];
    //
    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        return [self errorProcess:command code:errCodeInvalidMasterWalletManager msg:msg];
    }

    try {
        String mnemonic = mMasterWalletManager->GenerateMnemonic([self cstringWithString:language]);
        NSString *mnemonicString = [self stringWithCString:mnemonic];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:mnemonicString];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createSubWallet:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    try {
        ISubWallet *subWallet = masterWallet->CreateSubWallet(chainID);
        if (subWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@", @"CreateSubWallet", [self formatWalletNameWithString:masterWalletID other:chainID]];
            return [self errorProcess:command code:errCodeCreateSubWallet msg:msg];
        }
        Json json = subWallet->GetBasicInfo();
        NSString *jsonString = [self stringWithCString:json.dump()];

        [self addSubWalletListener:masterWalletID chainID:chainID];

        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }

}
- (void)getAllSubWallets:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }
    NSMutableArray *subWalletJsonArray = [[NSMutableArray alloc] init];

    try {
        ISubWalletVector subWalletList = masterWallet->GetAllSubWallets();
        for (int i = 0; i < subWalletList.size(); i++) {
            ISubWallet *iSubWallet = subWalletList[i];
            String chainId = iSubWallet->GetChainID();
            NSString *chainIdString = [self stringWithCString:chainId];
            [subWalletJsonArray addObject:chainIdString];
        }
        NSString *msg = [self arrayToJSONString:subWalletJsonArray];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)registerWalletListener:(CDVInvokedUrlCommand *)command
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setValue:command forKey:@"command"];
    [dict setValue:self.commandDelegate forKey:@"commandDelegate"];

    NSString *key = [NSString stringWithFormat:@"(%@:%@)", [self did], [self getModeId]];
    [subwalletListenerMDict setValue:dict forKey:key];
}

- (void)removeWalletListener:(CDVInvokedUrlCommand *)command
{
    NSString *key = [NSString stringWithFormat:@"(%@:%@)", [self did], [self getModeId]];
    [subwalletListenerMDict removeObjectForKey:key];
    return [self successAsString:command msg:@"remove listener"];
}

- (void)getBalance:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        String balance = subWallet->GetBalance();
        NSString *balanceStr = [self stringWithCString:balance];

        return [self successAsString:command msg:balanceStr];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getBalanceInfo:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->GetBalanceInfo();
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getSupportedChains:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    try {
        StringVector stringVec = masterWallet->GetSupportedChains();
        NSMutableArray *stringArray = [[NSMutableArray alloc] init];
        for(int i = 0; i < stringVec.size(); i++) {
            String string = stringVec[i];
            NSString *sstring = [self stringWithCString:string];
            [stringArray addObject:sstring];
        }

        CDVPluginResult*  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:stringArray];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getMasterWalletBasicInfo:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }
    NSString *jsonString = [self getBasicInfo:masterWallet];
    return [self successAsString:command msg:jsonString];
}

- (void)getAllTransaction:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    int    start          = [args[idx++] intValue];
    int    count          = [args[idx++] intValue];
    String addressOrTxId  = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID : chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->GetAllTransaction(start, count, addressOrTxId);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getLastBlockInfo:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID : chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->GetLastBlockInfo();
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createAddress:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        String address = subWallet->CreateAddress();
        NSString *jsonString = [self stringWithCString:address];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getGenesisAddress:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    ISidechainSubWallet *sidechainSubWallet = dynamic_cast<ISidechainSubWallet *>(subWallet);
    if(sidechainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of ISidechainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        String address = sidechainSubWallet->GetGenesisAddress();
        NSString *jsonString = [self stringWithCString:address];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)exportWalletWithKeystore:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String backupPassword = [self cstringWithString:args[idx++]];
    String payPassword = [self cstringWithString:args[idx++]];
    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    try {
        Json json = masterWallet->ExportKeystore(backupPassword, payPassword);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)exportWalletWithMnemonic:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String backupPassword = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    try {
        Json json = masterWallet->ExportMnemonic(backupPassword);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)verifyPassPhrase:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String passPhrase     = [self cstringWithString:args[idx++]];
    String payPassword    = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    try {
        masterWallet->VerifyPassPhrase(passPhrase, payPassword);
        return [self successAsString:command msg:@"Verify passPhrase OK"];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)verifyPayPassword:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String payPassword = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    try {
        masterWallet->VerifyPayPassword(payPassword);
        return [self successAsString:command msg:@"Verify pay password OK"];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)changePassword:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String oldPassword = [self cstringWithString:args[idx++]];
    String newPassword = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    try {
        masterWallet->ChangePassword(oldPassword, newPassword);
        return [self successAsString:command msg:@"Change password OK"];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getPubKeyInfo:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    try {
        masterWallet->GetPubKeyInfo();
        return [self successAsString:command msg:@"Get pubKey info OK"];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)importWalletWithKeystore:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    Json keystoreContent    = [self jsonWithString:args[idx++]];
    String backupPassword   = [self cstringWithString:args[idx++]];
    String payPassword      = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    try {
        IMasterWallet *masterWallet = mMasterWalletManager->ImportWalletWithKeystore(
                masterWalletID, keystoreContent, backupPassword, payPassword);
        if (masterWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Import", [self formatWalletName:masterWalletID], @"with keystore"];
            return [self errorProcess:command code:errCodeImportFromKeyStore msg:msg];
        }
        NSString *jsonString = [self getBasicInfo:masterWallet];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)importWalletWithMnemonic:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String mnemonic       = [self cstringWithString:args[idx++]];
    String phrasePassword = [self cstringWithString:args[idx++]];
    String payPassword    = [self cstringWithString:args[idx++]];
    Boolean singleAddress =  [args[idx++] boolValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    try {
        IMasterWallet *masterWallet = mMasterWalletManager->ImportWalletWithMnemonic(
                masterWalletID, mnemonic, phrasePassword, payPassword, singleAddress);
        if (masterWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"ImportWalletWithMnemonic", [self formatWalletName:masterWalletID], @"with mnemonic"];
            return [self errorProcess:command code:errCodeImportFromMnemonic msg:msg];
        }
        NSString *jsonString = [self getBasicInfo:masterWallet];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createMultiSignMasterWalletWithMnemonic:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String mnemonic       = [self cstringWithString:args[idx++]];
    String phrasePassword = [self cstringWithString:args[idx++]];
    String payPassword    = [self cstringWithString:args[idx++]];
    String str            = [self cstringWithString:args[idx++]];
    Json publicKeys       = Json::parse(str);
    int m                 = [args[idx++] intValue];
    long timestamp        = [args[idx++] longValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        return [self errorProcess:command code:errCodeInvalidMasterWalletManager msg:msg];
    }

    try {
        IMasterWallet *masterWallet = mMasterWalletManager->CreateMultiSignMasterWallet(
                masterWalletID, mnemonic, phrasePassword, payPassword, publicKeys, m, timestamp);
        if (masterWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Create multi sign", [self formatWalletName:masterWalletID], @"with mnemonic"];
            return [self errorProcess:command code:errCodeCreateMasterWallet msg:msg];
        }
        NSString *jsonString = [self getBasicInfo:masterWallet];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createMultiSignMasterWallet:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String str = [self cstringWithString:args[idx++]];
    Json publicKeys = Json::parse(str);
    int m = [args[idx++] intValue];
    long timestamp = [args[idx++] longValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        return [self errorProcess:command code:errCodeInvalidMasterWalletManager msg:msg];
    }

    try {
        IMasterWallet *masterWallet = mMasterWalletManager->CreateMultiSignMasterWallet(
                masterWalletID, publicKeys, m, timestamp);
        if (masterWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Create multi sign", [self formatWalletName:masterWalletID]];
            return [self errorProcess:command code:errCodeCreateMasterWallet msg:msg];
        }
        NSString *jsonString = [self getBasicInfo:masterWallet];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createMultiSignMasterWalletWithPrivKey:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String privKey        = [self cstringWithString:args[idx++]];
    String payPassword    = [self cstringWithString:args[idx++]];
    String str            = [self cstringWithString:args[idx++]];
    Json publicKeys       = Json::parse(str);
    int m                 = [args[idx++] intValue];
    long timestamp        = [args[idx++] longValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        return [self errorProcess:command code:errCodeInvalidMasterWalletManager msg:msg];
    }

    try {
        IMasterWallet *masterWallet = mMasterWalletManager->CreateMultiSignMasterWallet(
                masterWalletID, privKey, payPassword, publicKeys, m, timestamp);
        if (masterWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Create multi sign", [self formatWalletName:masterWalletID], @"with private key"];
            return [self errorProcess:command code:errCodeCreateMasterWallet msg:msg];
        }
        NSString *jsonString = [self getBasicInfo:masterWallet];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getAllAddress:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    int start             = [args[idx++] intValue];
    int count             = [args[idx++] intValue];
    Boolean internal      = [args[idx++] boolValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->GetAllAddress(start, count, internal);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getAllPublicKeys:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    int start             = [args[idx++] intValue];
    int count             = [args[idx++] intValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->GetAllPublicKeys(start, count);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)isAddressValid:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String addr             = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    Boolean valid = masterWallet->IsAddressValid(addr);
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    ret[@"isValid"] = (valid? @YES : @NO);

    CDVPluginResult*  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:ret];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)isSubWalletAddressValid:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    String address          = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }

    Boolean valid = masterWallet->IsSubWalletAddressValid(chainID, address);

    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    ret[@"isValid"] = (valid? @YES : @NO);

    CDVPluginResult*  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:ret];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)createDepositTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID    = [self cstringWithString:args[idx++]];
    String chainID           = [self cstringWithString:args[idx++]];
    String fromAddress       = [self cstringWithString:args[idx++]];
    String lockedAddress     = [self cstringWithString:args[idx++]];
    String amount            = [self cstringWithString:args[idx++]];
    String sideChainAddress  = [self cstringWithString:args[idx++]];
    String memo              = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json json = mainchainSubWallet->CreateDepositTransaction(fromAddress, lockedAddress, amount, sideChainAddress, memo);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)destroyWallet:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_semaphore_wait(walletSemaphore, DISPATCH_TIME_FOREVER);

        IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
        if (masterWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
            return [self errorProcess:command code:self->errCodeInvalidMasterWallet msg:msg];
        }

        ISubWalletVector subWallets = masterWallet->GetAllSubWallets();
        for (int i = 0; i < subWallets.size(); i++) {
            subWallets[i]->SyncStop();
            subWallets[i]->RemoveCallback();
            masterWallet->DestroyWallet(subWallets[i]->GetChainID());
        }

        if (mMasterWalletManager == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
            return [self errorProcess:command code:self->errCodeInvalidMasterWalletManager msg:msg];
        }

        try {
            mMasterWalletManager->DestroyWallet(masterWalletID);
            dispatch_semaphore_signal(walletSemaphore);
            NSString *msg = [NSString stringWithFormat:@"Destroy %@ OK", [self formatWalletName:masterWalletID]];
            return [self successAsString:command msg:msg];
        } catch (const std:: exception &e) {
            dispatch_semaphore_signal(walletSemaphore);
            return [self exceptionProcess:command string:e.what()];
        }
    });
}

- (void)createTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String fromAddress    = [self cstringWithString:args[idx++]];
    String toAddress      = [self cstringWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->CreateTransaction(fromAddress, toAddress, amount, memo);
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getAllUTXOs:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    int start             = [args[idx++] intValue];
    int count             = [args[idx++] intValue];
    String address        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json result = subWallet->GetAllUTXOs(start, count, address);
        NSString *msg = [self stringWithJson:result];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createConsolidateTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json result = subWallet->CreateConsolidateTransaction(memo);
        NSString *msg = [self stringWithJson:result];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)signTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json rawTransaction   = [self jsonWithString:args[idx++]];
    String payPassword    = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json result = subWallet->SignTransaction(rawTransaction, payPassword);
        NSString *msg = [self stringWithJson:result];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)publishTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json rawTxJson        =  [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json result = subWallet->PublishTransaction(rawTxJson);
        NSString *msg = [self stringWithJson:result];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getTransactionSignedInfo:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json rawTxJson        = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json resultJson = subWallet->GetTransactionSignedInfo(rawTxJson);
        NSString *jsonString = [self stringWithJson:resultJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createIdTransaction:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json payloadJson      = [self jsonWithDict:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IIDChainSubWallet *idchainSubWallet = dynamic_cast<IIDChainSubWallet *>(subWallet);
    if(idchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"is not instance of IIDChainSubWallet", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json json = idchainSubWallet->CreateIDTransaction(payloadJson, memo);
        NSString *msg = [self stringWithJson:json];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createWithdrawTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String fromAddress    = [self cstringWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String mainchainAddress  = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    ISidechainSubWallet *sidechainSubWallet = dynamic_cast<ISidechainSubWallet *>(subWallet);
    if(sidechainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of ISidechainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json json = sidechainSubWallet->CreateWithdrawTransaction(fromAddress, amount, mainchainAddress, memo);
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getMasterWallet:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }
    NSString *jsonString = [self getBasicInfo:masterWallet];
    return [self successAsString:command msg:jsonString];
}

- (void)destroySubWallet:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletName:masterWalletID]];
        return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        subWallet->SyncStop();
        subWallet->RemoveCallback();
        masterWallet->DestroyWallet(chainID);

        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Destroy", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getVersion:(CDVInvokedUrlCommand *)command
{
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        return [self errorProcess:command code:errCodeInvalidMasterWalletManager msg:msg];
    }
    String version = mMasterWalletManager->GetVersion();
    NSString *msg = [self stringWithCString:version];
    return [self successAsString:command msg:msg];
}

- (void)setLogLevel:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    String loglevel = [self cstringWithString:args[idx++]];
    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        return [self errorProcess:command code:errCodeInvalidMasterWalletManager msg:msg];
    }
    mMasterWalletManager->SetLogLevel(loglevel);
    return [self successAsString:command msg:@"SetLogLevel OK"];
}

- (void)generateProducerPayload:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String publicKey      = [self cstringWithString:args[idx++]];
    String nodePublicKey  = [self cstringWithString:args[idx++]];
    String nickName       = [self cstringWithString:args[idx++]];
    String url            = [self cstringWithString:args[idx++]];
    String IPAddress      = [self cstringWithString:args[idx++]];
    long   location       = [args[idx++] longValue];
    String payPasswd      = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json payloadJson = mainchainSubWallet->GenerateProducerPayload(publicKey, nodePublicKey, nickName, url, IPAddress, location, payPasswd);
        NSString *jsonString = [self stringWithJson:payloadJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)generateCancelProducerPayload:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String publicKey      = [self cstringWithString:args[idx++]];
    String payPasswd      = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        String payloadJson = mainchainSubWallet->GenerateCancelProducerPayload(publicKey, payPasswd);
        NSString *jsonString = [self stringWithJson:payloadJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createRegisterProducerTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String fromAddress    = [self cstringWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson = mainchainSubWallet->CreateRegisterProducerTransaction(fromAddress, payloadJson, amount, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createUpdateProducerTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String fromAddress    = [self cstringWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson = mainchainSubWallet->CreateUpdateProducerTransaction(fromAddress, payloadJson, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createCancelProducerTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String fromAddress    = [self cstringWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson =  mainchainSubWallet->CreateCancelProducerTransaction(fromAddress, payloadJson, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createRetrieveDepositTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson =  mainchainSubWallet->CreateRetrieveDepositTransaction(amount, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getOwnerPublicKey:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    String msg = mainchainSubWallet->GetOwnerPublicKey();
    NSString *jsonString = [self stringWithCString:msg];
    return [self successAsString:command msg:jsonString];
}

- (void)createVoteProducerTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID  = [self cstringWithString:args[idx++]];
    String chainID         = [self cstringWithString:args[idx++]];
    String fromAddress     = [self cstringWithString:args[idx++]];
    String stake           = [self cstringWithString:args[idx++]];
    Json publicKeys        = [self jsonWithString:args[idx++]];
    String memo            = [self cstringWithString:args[idx++]];
    Json invalidCandidates = Json::parse("[]");

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson = mainchainSubWallet->CreateVoteProducerTransaction(fromAddress, stake, publicKeys, memo, invalidCandidates);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getVotedProducerList:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json json = mainchainSubWallet->GetVotedProducerList();
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getRegisteredProducerInfo:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json json = mainchainSubWallet->GetRegisteredProducerInfo();
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

// CR
- (void)generateCRInfoPayload:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String crPublicKey    = [self cstringWithString:args[idx++]];
    String did            = [self cstringWithString:args[idx++]];
    String nickName       = [self cstringWithString:args[idx++]];
    String url            = [self cstringWithString:args[idx++]];
    long   location       = [args[idx++] longValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json payloadJson = mainchainSubWallet->GenerateCRInfoPayload(crPublicKey, did, nickName, url, location);
        NSString *jsonString = [self stringWithJson:payloadJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)generateUnregisterCRPayload:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String did            = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json payloadJson = mainchainSubWallet->GenerateUnregisterCRPayload(did);
        NSString *jsonString = [self stringWithJson:payloadJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createRegisterCRTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String fromAddress    = [self cstringWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson = mainchainSubWallet->CreateRegisterCRTransaction(fromAddress, payloadJson, amount, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createUpdateCRTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String fromAddress    = [self cstringWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson = mainchainSubWallet->CreateUpdateCRTransaction(fromAddress, payloadJson, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createUnregisterCRTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String fromAddress    = [self cstringWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson =  mainchainSubWallet->CreateUnregisterCRTransaction(fromAddress, payloadJson, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createRetrieveCRDepositTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String crPublicKey    = [self cstringWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson =  mainchainSubWallet->CreateRetrieveCRDepositTransaction(crPublicKey, amount, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)CRCouncilMemberClaimNodeDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String payload        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson =  mainchainSubWallet->CRCouncilMemberClaimNodeDigest(payload);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createCRCouncilMemberClaimNodeTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String payload        = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson =  mainchainSubWallet->CreateCRCouncilMemberClaimNodeTransaction(payload, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createVoteCRTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID  = [self cstringWithString:args[idx++]];
    String chainID         = [self cstringWithString:args[idx++]];
    String fromAddress     = [self cstringWithString:args[idx++]];
    Json publicKeys        = [self jsonWithDict:args[idx++]];
    String memo            = [self cstringWithString:args[idx++]];
    Json invalidCandidates = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson = mainchainSubWallet->CreateVoteCRTransaction(fromAddress, publicKeys, memo, invalidCandidates);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getVotedCRList:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json json = mainchainSubWallet->GetVotedCRList();
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getRegisteredCRInfo:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json json = mainchainSubWallet->GetRegisteredCRInfo();
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getVoteInfo:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID  = [self cstringWithString:args[idx++]];
    String chainID         = [self cstringWithString:args[idx++]];
    String type            = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json txJson = mainchainSubWallet->GetVoteInfo(type);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)proposalOwnerDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    String payload          = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if (mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->ProposalOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)proposalCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID       = [self cstringWithString:args[idx++]];
    String chainID              = [self cstringWithString:args[idx++]];
    String payload              = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->ProposalCRCouncilMemberDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)calculateProposalHash:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID       = [self cstringWithString:args[idx++]];
    String chainID              = [self cstringWithString:args[idx++]];
    String payload              = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->CalculateProposalHash(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createProposalTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json crSignedProposal   = [self jsonWithString:args[idx++]];
    String memo             = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->CreateProposalTransaction(crSignedProposal, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)proposalReviewDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    String payload          = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->ProposalReviewDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createProposalReviewTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String memo             = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->CreateProposalReviewTransaction(payload, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)proposalTrackingOwnerDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->ProposalTrackingOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)proposalTrackingNewOwnerDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->ProposalTrackingNewOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)proposalTrackingSecretaryDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->ProposalTrackingSecretaryDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)proposalWithdrawDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->ProposalWithdrawDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createProposalWithdrawTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    String payload          = [self cstringWithString:args[idx++]];
    String memo             = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->CreateProposalWithdrawTransaction(payload, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createVoteCRCProposalTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    String fromAddress      = [self cstringWithString:args[idx++]];
    Json votes              = [self jsonWithString:args[idx++]];
    String memo             = [self cstringWithString:args[idx++]];
    Json invalidCandidates  = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->CreateVoteCRCProposalTransaction(fromAddress, votes, memo, invalidCandidates);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createImpeachmentCRCTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    String fromAddress      = [self cstringWithString:args[idx++]];
    Json votes              = [self jsonWithString:args[idx++]];
    String memo             = [self cstringWithString:args[idx++]];
    Json invalidCandidates  = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->CreateImpeachmentCRCTransaction(fromAddress, votes, memo, invalidCandidates);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createProposalTrackingTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    String proposalTracking = [self cstringWithString:args[idx++]];
    String memo             = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->CreateProposalTrackingTransaction(proposalTracking, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

// Proposal Secretary General Election
- (void)proposalSecretaryGeneralElectionDigest:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

- (void)proposalSecretaryGeneralElectionCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

- (void)createSecretaryGeneralElectionTransaction:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

// Proposal Change Owner
- (void)proposalChangeOwnerDigest:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

- (void)proposalChangeOwnerCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

- (void)createProposalChangeOwnerTransaction:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

// Proposal Terminate Proposal
- (void)terminateProposalOwnerDigest:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

- (void)terminateProposalCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

- (void)createTerminateProposalTransaction:(CDVInvokedUrlCommand *)command
{
    return [self exceptionProcess:command string:"TODO"];
}

- (void)syncStart:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID       = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
        if (subWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
            return [self errorProcess:command code:self->errCodeInvalidSubWallet msg:msg];
        }

        subWallet->SyncStart();
        return [self successAsString:command msg:@"SyncStart OK"];
    });
}

- (void)syncStop:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID       = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
        if (subWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
            return [self errorProcess:command code:self->errCodeInvalidSubWallet msg:msg];
        }

        subWallet->SyncStop();
        return [self successAsString:command msg:@"SyncStop OK"];
     });
}

- (void)reSync:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID       = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    subWallet->Resync();
    return [self successAsString:command msg:@"SyncStop OK"];
}

String const IDChain = "IDChain";

- (IIDChainSubWallet*) getIDChainSubWallet:(String)masterWalletID {
     ISubWallet* subWallet = [self getSubWallet:masterWalletID :IDChain];

    return dynamic_cast<IIDChainSubWallet *>(subWallet);
 }

- (void)getAllDID:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    int start = [args[idx++] intValue];
    int count = [args[idx++] intValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:masterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:IDChain]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = idChainSubWallet->GetAllDID(start, count);
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)didSign:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String did            = [self cstringWithString:args[idx++]];
    String message        = [self cstringWithString:args[idx++]];
    String payPassword    = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:masterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:IDChain]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        String ret = idChainSubWallet->Sign(did, message, payPassword);
        NSString *jsonString = [self stringWithJson:ret];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)didSignDigest:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String did            = [self cstringWithString:args[idx++]];
    String digest        = [self cstringWithString:args[idx++]];
    String payPassword    = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:masterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:IDChain]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        String ret = idChainSubWallet->SignDigest(did, digest, payPassword);
        NSString *jsonString = [self stringWithJson:ret];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)verifySignature:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String publicKey            = [self cstringWithString:args[idx++]];
    String message        = [self cstringWithString:args[idx++]];
    String signature    = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:masterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:IDChain]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Boolean ret = idChainSubWallet->VerifySignature(publicKey, message, signature);
        CDVPluginResult*  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:ret];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getPublicKeyDID:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String publicKey      = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:masterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:IDChain]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        String ret = idChainSubWallet->GetPublicKeyDID(publicKey);
        NSString *jsonString = [self stringWithJson:ret];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getPublicKeyCID:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String publicKey      = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:masterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:IDChain]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        String ret = idChainSubWallet->GetPublicKeyCID(publicKey);
        NSString *jsonString = [self stringWithJson:ret];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

String const ETHSC = "ETHSC";

- (IEthSidechainSubWallet*) getEthSidechainSubWallet:(String)masterWalletID {
     ISubWallet* subWallet = [self getSubWallet:masterWalletID :ETHSC];

    return dynamic_cast<IEthSidechainSubWallet *>(subWallet);
 }

- (void)createTransfer:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String targetAddress  = [self cstringWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    int amountUnit        = [args[idx++] intValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IEthSidechainSubWallet* ethscSubWallet = [self getEthSidechainSubWallet:masterWalletID];
    if (ethscSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:ETHSC]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = ethscSubWallet->CreateTransfer(targetAddress, amount, amountUnit);
        NSString *msg = [self stringWithJson:json];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)createTransferGeneric:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String targetAddress  = [self cstringWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    int amountUnit        = [args[idx++] intValue];
    String gasPrice       = [self cstringWithString:args[idx++]];
    int gasPriceUnit      = [args[idx++] intValue];
    String gasLimit       = [self cstringWithString:args[idx++]];
    String data           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IEthSidechainSubWallet* ethscSubWallet = [self getEthSidechainSubWallet:masterWalletID];
    if (ethscSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:ETHSC]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = ethscSubWallet->CreateTransferGeneric(targetAddress, amount, amountUnit, gasPrice, gasPriceUnit, gasLimit, data);
        NSString *msg = [self stringWithJson:json];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)deleteTransfer:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String tx             = [self stringWithDict:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IEthSidechainSubWallet* ethscSubWallet = [self getEthSidechainSubWallet:masterWalletID];
    if (ethscSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:ETHSC]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        ethscSubWallet->DeleteTransfer(nlohmann::json::parse(tx));
        return [self successAsString:command msg:@"DeleteTransfer OK"];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getTokenTransactions:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    int    start          = [args[idx++] intValue];
    int    count          = [args[idx++] intValue];
    String txid           = [self cstringWithString:args[idx++]];
    String tokenSymbol    = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IEthSidechainSubWallet* ethscSubWallet = [self getEthSidechainSubWallet:masterWalletID];
    if (ethscSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:ETHSC]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = ethscSubWallet->GetTokenTransactions(start, count, txid, tokenSymbol);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)getERC20TokenList:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    String address = [self cstringWithString:args[0]];

    WalletHttprequest* walletHttprequest = new WalletHttprequest(mEthscGetTokenListUrl);
    if (walletHttprequest == nil) {
        NSString *msg = @"getERC20TokenList: fail to new WalletHttprequest.";
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        try {
            NSString *jsonString = walletHttprequest->GetTokenListByAddress(address);
            NSDictionary *dic = [self dictionaryWithJsonString:jsonString];

            NSArray * tokenList = [dic objectForKey:@"result"];
            return [self successAsArray:command msg:tokenList];
        } catch (const std:: exception &e) {
            return [self exceptionProcess:command string:e.what()];
        }
    });
}

- (void)getBackupInfo:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[0]];

        try {
            IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
            if (masterWallet == nil) {
                NSString *msg = [NSString stringWithFormat:@"Master wallet %@ not found", [self formatWalletNameWithString:masterWalletID other:IDChain]];
                return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
            }

            String spvSyncStateFilesPath = [self getSPVSyncStateFolderPath:masterWalletID];
            NSDictionary *backupInfo = [[NSDictionary alloc] init];
            //[backupInfo setValue:@"hey" forKey:@"test"];

            // TODO - NOT IMPLEMENTED YET

            // ELA mainchain info
            /*JSONObject elaDatabaseInfo = new JSONObject();
            File elaDBFile = new File(spvSyncStateFilesPath + "/ELA.db");
            if (elaDBFile.exists()) {
                elaDatabaseInfo.put("fileName", "ELA.db");
                elaDatabaseInfo.put("fileSize", elaDBFile.length());
                elaDatabaseInfo.put("lastModified", elaDBFile.lastModified()); // Timestamp MS
                backupInfo.put("ELADatabase", elaDatabaseInfo);
            }

            // ID sidechain info
            JSONObject idChainDatabaseInfo = new JSONObject();
            File idChainDBFile = new File(spvSyncStateFilesPath + "/IDChain.db");
            if (idChainDBFile.exists()) {
                idChainDatabaseInfo.put("fileName", "IDChain.db");
                idChainDatabaseInfo.put("fileSize", idChainDBFile.length());
                idChainDatabaseInfo.put("lastModified", idChainDBFile.lastModified()); // Timestamp MS
                backupInfo.put("IDChainDatabase", idChainDatabaseInfo);
            }

            // ETH sidechain info
            JSONObject ethChainDatabaseInfo = new JSONObject();
            File ethChainDBFile = new File(spvSyncStateFilesPath + "/eth-mainnet-entities.db");
            if (ethChainDBFile.exists()) {
                ethChainDatabaseInfo.put("fileName", "eth-mainnet-entities.db");
                ethChainDatabaseInfo.put("fileSize", ethChainDBFile.length());
                ethChainDatabaseInfo.put("lastModified", ethChainDBFile.lastModified()); // Timestamp MS
                backupInfo.put("IDChainDatabase", ethChainDatabaseInfo);
            }
*/
            //return [self successAsDict:command msg:backupInfo];
            return [self exceptionProcess:command string:"NOT IMPLEMENTED"]; // TMP
        } catch (const std:: exception &e) {
            return [self exceptionProcess:command string:e.what()];
        }
    }

-(void)getBackupFile:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[0]];
    String fileName = [self cstringWithString:args[1]];

        try {
            IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
            if (masterWallet == nil) {
                NSString *msg = [NSString stringWithFormat:@"Master wallet %@ not found", [self formatWalletNameWithString:masterWalletID other:IDChain]];
                return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
            }

            if (![self ensureBackupFile:fileName]) {
                NSString *msg = [NSString stringWithFormat:@"Invalid backup file name %s", fileName.c_str()];
                return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
            }

            try {
                // Open an input stream to read the file
                String spvSyncStateFilesPath = [self getSPVSyncStateFolderPath:masterWalletID];

                NSString *backupFilePath =  [NSString stringWithFormat:@"%s/%s", spvSyncStateFilesPath.c_str(), fileName.c_str()];
                NSFileHandle * backupFile = [NSFileHandle fileHandleForReadingAtPath:backupFilePath];

                NSString *objectId = [NSString stringWithFormat:@"%lu", (unsigned long)backupFile.hash];
                backupFileReaderMap[objectId] = backupFile;

                NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
                ret[@"objectId"] = objectId;
                return [self successAsDict:command msg:ret];
            } catch (const std:: exception &e) {
                return [self exceptionProcess:command string:e.what()];
            }
        } catch (const std:: exception &e) {
            return [self exceptionProcess:command string:e.what()];
        }
    }

-(void)backupFileReader_read:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    String readerObjectId = [self cstringWithString:args[0]];
    int bytesCount = [args[1] intValue];

    try {
        NSFileHandle *reader = (NSFileHandle*)backupFileReaderMap[[self stringWithCString:readerObjectId.c_str()]];

        NSData *buffer = [reader readDataOfLength:bytesCount];

        if (buffer != nil) {
            [self successAsString:command msg:[buffer base64EncodedStringWithOptions: kNilOptions]];
        }
        else {
            [self successAsString:command msg:nil];
        }
    }
    catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

- (void)backupFileReader_close:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    NSString *readerObjectId = args[0];

    try {
        NSFileHandle *reader = (NSFileHandle*)backupFileReaderMap[readerObjectId];
        [reader closeFile];
        [backupFileReaderMap removeObjectForKey:readerObjectId];
        [self successAsString:command msg:nil];
    }
    catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

-(void)restoreBackupFile:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[0]];
    String fileName = [self cstringWithString:args[1]];

    try {
        IMasterWallet *masterWallet = [self getIMasterWallet:masterWalletID];
        if (masterWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"Master wallet %@ not found", [self formatWalletNameWithString:masterWalletID other:IDChain]];
            return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
        }

        if (![self ensureBackupFile:fileName]) {
            NSString *msg = [NSString stringWithFormat:@"Invalid backup file name %s", fileName.c_str()];
            return [self errorProcess:command code:errCodeInvalidMasterWallet msg:msg];
        }

        try {
            // Open an output stream to write the file
            String spvSyncStateFilesPath = [self getSPVSyncStateFolderPath:masterWalletID];
            NSString *backupFilePath =  [NSString stringWithFormat:@"%s/%s", spvSyncStateFilesPath.c_str(), fileName.c_str()];
            NSLog(@"Wallet writer - Using SPV file path: %@", backupFilePath);
            tmpDebug = backupFilePath;

            NSFileHandle * backupFile = [NSFileHandle fileHandleForWritingAtPath:backupFilePath];

            NSString *objectId = [NSString stringWithFormat:@"%lu", (unsigned long)backupFile.hash];
            backupFileWriterMap[objectId] = backupFile;

            NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
            ret[@"objectId"] = objectId;
            return [self successAsDict:command msg:ret];
        } catch (const std:: exception &e) {
            return [self exceptionProcess:command string:e.what()];
        }
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

-(void)backupFileWriter_write:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    NSString *writerObjectId = args[0];
    NSData *data = args[1];

    try {
        NSFileHandle *writer = (NSFileHandle*)backupFileWriterMap[writerObjectId];
        if (writer == nil) {
            return [self exceptionProcess:command string:"Nil writer object in backupFileWriter_write()"];
        }

        if (data == nil) {
            return [self exceptionProcess:command string:"Nil data received in backupFileWriter_write()"];
        }

        [writer writeData:data];
        [self successAsString:command msg:nil];
    }
    catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

NSString *tmpDebug;
- (void)backupFileWriter_close:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    NSString *writerObjectId = args[0];

    try {
        NSFileHandle *writer = (NSFileHandle*)backupFileWriterMap[writerObjectId];
        [writer closeFile];
        NSLog(@"Wallet writer - Closed file");

        /*{
            // DEBUG
            NSString *backupFilePath = tmpDebug;
            NSLog(@"Wallet writer - DEBUGGING SPV file path: %@", backupFilePath);

            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:backupFilePath error:nil];

            NSLog(@"Wallet writer - FILE SIZE: %llu", [attributes fileSize]);
            NSLog(@"Wallet writer - MODIF DATE: %@", [attributes fileModificationDate]);
        }*/

        [backupFileWriterMap removeObjectForKey:writerObjectId];
        [self successAsString:command msg:nil];
    }
    catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what()];
    }
}

-(String)getSPVSyncStateFolderPath:(String)masterWalletID
{
    if ([netType isEqual: @"TestNet"]) {
        return [[NSString stringWithFormat:@"%@/spv/data/TestNet/%@", [self getDataPath], [self stringWithCString:masterWalletID]] UTF8String];
    } else {
        return [[NSString stringWithFormat:@"%@/spv/data/%@", [self getDataPath], [self stringWithCString:masterWalletID]] UTF8String];
    }
}

// Returns true if the given filename is a valid wallet file for backup (to make sure we the caller is not
// trying to access and unauthorized file), false otherwise.
-(bool)ensureBackupFile:(String)fileName {
    return fileName == "ELA.db" || fileName == "IDChain.db";
}

@end
