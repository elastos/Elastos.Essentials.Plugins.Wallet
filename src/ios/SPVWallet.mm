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

#import "SPVWallet.h"
#import "IMasterWallet.h"
#import "WrapSwift.h"
#import "MasterWalletManager.h"
#import "ISidechainSubWallet.h"
#import "IMainchainSubWallet.h"
#import "IIDChainSubWallet.h"
#import <string.h>
#import <map>

#pragma mark - SPVSubWalletCallback C++

using namespace Elastos::ElaWallet;

typedef Elastos::ElaWallet::IMasterWallet IMasterWallet;
typedef Elastos::ElaWallet::MasterWalletManager MasterWalletManager;
typedef Elastos::ElaWallet::ISubWallet ISubWallet;
typedef std::string String;
typedef nlohmann::json Json;
typedef std::vector<IMasterWallet *> IMasterWalletVector;
typedef std::vector<ISubWallet *> ISubWalletVector;
typedef std::vector<String> StringVector;

typedef Elastos::ElaWallet::ISubWalletCallback ISubWalletCallback;
typedef Elastos::ElaWallet::ISidechainSubWallet ISidechainSubWallet;
typedef Elastos::ElaWallet::IMainchainSubWallet IMainchainSubWallet;
typedef std::vector<ISubWalletCallback *> ISubWalletCallbackVector;
typedef Elastos::ElaWallet::IIDChainSubWallet IIDChainSubWallet;

class SPVSubWalletCallback: public ISubWalletCallback
{
public:
    SPVSubWalletCallback(id <ElISubWalletDelegate> delegate, String &masterWalletID, String &chainID);

    ~SPVSubWalletCallback();

    void OnTransactionStatusChanged(const std::string &txid, const std::string &status, const nlohmann::json &desc, uint32_t confirms);
    void OnBalanceChanged(const std::string &asset, const std::string & balance);
    void OnBlockSyncProgress(const nlohmann::json &progressInfo);
    void OnTxPublished(const std::string &hash, const nlohmann::json &result);
    void OnAssetRegistered(const std::string &asset, const nlohmann::json &info);
    void OnConnectStatusChanged(const std::string &status);

private:
    id <ElISubWalletDelegate> commandDelegate;
    NSString * mMasterWalletID;
    NSString * mSubWalletID;
    NSString *keySuccess;//   = @"success";
    NSString *keyError;//     = "error";
    NSString *keyCode;//      = "code";
    NSString *keyMessage;//   = "message";
    NSString *keyException;// = "exception";
};

SPVSubWalletCallback::SPVSubWalletCallback(id <ElISubWalletDelegate> delegate,
                                           String &masterWalletID,
                                           String &chainID)
{
    mMasterWalletID = [NSString stringWithCString:masterWalletID.c_str() encoding:NSUTF8StringEncoding];
    mSubWalletID = [NSString stringWithCString:chainID.c_str() encoding:NSUTF8StringEncoding];
    commandDelegate = delegate;
    keySuccess   = @"success";
    keyError     = @"error";
    keyCode      = @"code";
    keyMessage   = @"message";
    keyException = @"exception";
}
SPVSubWalletCallback::~SPVSubWalletCallback()
{
}

void SPVSubWalletCallback::OnTransactionStatusChanged(const std::string &txid,
                                                      const std::string &status,
                                                      const nlohmann::json &desc,
                                                      uint32_t confirms)
{
    NSLog(@" ----OnTransactionStatusChanged ----\n");
    NSString *txIdStr = [NSString stringWithCString:txid.c_str() encoding:NSUTF8StringEncoding];
    NSString *statusStr = [NSString stringWithCString:status.c_str() encoding:NSUTF8StringEncoding];
    NSString *descStr = [NSString stringWithCString:desc.dump().c_str() encoding:NSUTF8StringEncoding];
    NSNumber *confirmNum = [NSNumber numberWithInt:confirms];
    [commandDelegate onTransactionStatusChangedTxId:txIdStr
                                             status:statusStr
                                               desc:descStr
                                            confirm:confirmNum];
}

void SPVSubWalletCallback::OnBlockSyncProgress(const nlohmann::json &progressInfo)
{
    NSLog(@" ----OnBlockSyncProgress ----\n");
    NSString *progressInfoString = [NSString stringWithCString:progressInfo.dump().c_str() encoding:NSUTF8StringEncoding];
    NSError *err;
    NSMutableDictionary *dict = [NSJSONSerialization JSONObjectWithData:[progressInfoString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&err];
    [dict setValue:@"OnBlockSyncProgress" forKey:@"Action"];
    [dict setValue:mMasterWalletID forKey:@"MasterWalletID"];
    [dict setValue:mSubWalletID forKey:@"ChainID"];

    [commandDelegate onBlockSyncProgressWithProgressInfo:dict];
}

void SPVSubWalletCallback::OnBalanceChanged(const std::string &asset, const std::string &balance)
{
    NSLog(@" ----OnBalanceChanged ----\n");
    NSString *assetString = [NSString stringWithCString:asset.c_str() encoding:NSUTF8StringEncoding];
    NSString *balanceString = [NSString stringWithCString:balance.c_str() encoding:NSUTF8StringEncoding];
    [commandDelegate onBalanceChangedAsset:assetString balance:balanceString];
}

void SPVSubWalletCallback::OnTxPublished(const std::string &hash, const nlohmann::json &result)
{
    NSLog(@" ----OnTxPublished ----\n");
    NSString *hashString = [NSString stringWithCString:hash.c_str() encoding:NSUTF8StringEncoding];
    NSString *resultString = [NSString stringWithCString:result.dump().c_str() encoding:NSUTF8StringEncoding];
    if (resultString == nil) {
        NSLog(@"OnTxPublished error");
    }
    NSData *jsonData = [resultString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) {
        NSLog(@"OnTxPublished error: %@", err);
    }

    [commandDelegate onTxPublishedHash:hashString result:dic];
}

void SPVSubWalletCallback::OnAssetRegistered(const std::string &asset, const nlohmann::json &info)
{
    NSLog(@" ----OnAssetRegistered ----\n");
    NSString *assetString = [NSString stringWithCString:asset.c_str() encoding:NSUTF8StringEncoding];
    NSString *infoString = [NSString stringWithCString:info.dump().c_str() encoding:NSUTF8StringEncoding];
    [commandDelegate onAssetRegisteredAsset:assetString info:infoString];
}

void SPVSubWalletCallback::OnConnectStatusChanged(const std::string &status)
{
    NSLog(@" ----OnConnectStatusChanged ----\n");
    NSString *statusString = [NSString stringWithCString:status.c_str() encoding:NSUTF8StringEncoding];
    [commandDelegate onConnectStatusChangedStatus:statusString];
}

#pragma mark - Wallet
@implementation SPVWallet
NSString *TAG = @"Wallet";
MasterWalletManager *mMasterWalletManager;// = null;
NSString *mRootPath;// = null;

NSString *keySuccess = @"success";
NSString *keyError = @"error";
NSString *keyCode = @"code";
NSString *keyMessage = @"message";
NSString *keyException = @"exception";

int errCodeParseJsonInAction          = 10000;
int errCodeInvalidArg                 = 10001;
int errCodeInvalidMasterWallet        = 10002 ;
int errCodeInvalidSubWallet           = 10003;
int errCodeCreateMasterWallet         = 10004;
int errCodeCreateSubWallet            = 10005;
int errCodeRecoverSubWallet           = 10006;
int errCodeInvalidMasterWalletManager = 10007;
int errCodeImportFromKeyStore         = 10008;
int errCodeImportFromMnemonic         = 10009;
int errCodeSubWalletInstance          = 10010;
int errCodeInvalidDIDManager          = 10011;
int errCodeInvalidDID                 = 10012;
int errCodeActionNotFound             = 10013;
int errCodeWalletException             = 20000;

static SPVWallet * _instance;

+(instancetype)sharedWallet{
    return [[self alloc]init];
}

+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return _instance;
}

- (nonnull id)mutableCopyWithZone:(nullable NSZone *)zone {
    return _instance;
}
- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)setInfo:(NSObject *)info {
    [super setInfo:info];
    NSString* rootPath = [[self getDataPath] stringByAppendingString:@"spv"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:rootPath]) {
        [fm createDirectoryAtPath:rootPath withIntermediateDirectories:true attributes:NULL error:NULL];
    }

    NSString* dataPath = [rootPath stringByAppendingString:@"/data"];
    if (![fm fileExistsAtPath:dataPath]) {
        [fm createDirectoryAtPath:dataPath withIntermediateDirectories:true attributes:NULL error:NULL];
    }
    NSString* netType = [WrapSwift getNetworkType];
    NSString* config = [WrapSwift getNetworkConfig];
    mMasterWalletManager = new MasterWalletManager([rootPath UTF8String], [netType UTF8String]
                                                   , [config UTF8String], [dataPath UTF8String]);
}

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
- (NSDictionary *)getBasicInfo:(IMasterWallet *)masterWallet
{
    Json json = masterWallet->GetBasicInfo();
    return [self dictWithJson:json];
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

- (NSDictionary *)dictWithJson:(Json)json
{
    NSString *jsonString = [self stringWithCString:json.dump()];
    if (jsonString == nil) {
        return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) {
        return nil;
    }
    return dic;
}


- (NSArray *)arraytWithJson:(Json)json
{
    NSString *jsonString = [self stringWithCString:json.dump()];
    if (jsonString == nil) {
        return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) {
        return nil;
    }
    return array;
}

- (NSString *)stringWithJson:(Json)json
{
    return [self stringWithCString:json.dump()];
}
//String 转 NSString
- (NSString *)stringWithCString:(String)string
{
    NSString *str = [NSString stringWithCString:string.c_str() encoding:NSUTF8StringEncoding];
    //    str = [str stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    //    str = [str stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];
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

- (NSArray *)getAllMasterWallets {

    IMasterWalletVector vector = mMasterWalletManager->GetAllMasterWallets();
    NSMutableArray *masterWalletListJson = [[NSMutableArray alloc] init];
    for (int i = 0; i < vector.size(); i++) {
        IMasterWallet *iMasterWallet = vector[i];
        String idStr = iMasterWallet->GetID();
        NSString *str = [self stringWithCString:idStr];
        [masterWalletListJson addObject:str];
    }
    return masterWalletListJson;
}

- (NSDictionary *)createMasterWalletWithMasterWalletID:(NSString *)masterWalletID
                                              mnemonic:(NSString *)mnemonic
                                        phrasePassword:(NSString *)phrasePassword
                                           payPassword:(NSString *)payPassword
                                         singleAddress:(NSNumber *)singleAddress
                                                 error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cmnemonic       = [self cstringWithString:mnemonic];
    String cphrasePassword = [self cstringWithString:phrasePassword];
    String cpayPassword    = [self cstringWithString:payPassword];
    Boolean csingleAddress = [singleAddress boolValue];
    IMasterWallet *masterWallet = mMasterWalletManager->CreateMasterWallet(
                                                                           cmasterWalletID,
                                                                           cmnemonic,
                                                                           cphrasePassword,
                                                                           cpayPassword,
                                                                           csingleAddress);
    if (masterWallet == NULL) {
        NSString *msg = [NSString stringWithFormat:@"Create %@", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if(error){
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    if (masterWallet == NULL) {
        NSString *msg = [NSString stringWithFormat:@"Create %@", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if(error){
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    NSDictionary *json = [self getBasicInfo:masterWallet];
    return json;
}

- (NSString *)generateMnemonicWithLanguage:(NSString *)language
                                     error:(NSError **)error
{
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    String mnemonic = mMasterWalletManager->GenerateMnemonic([self cstringWithString:language]);
    NSString *mnemonicString = [self stringWithCString:mnemonic];
    return mnemonicString;
}

- (NSDictionary *)createSubWallet:(NSString *)masterWalletID
                          chainID:(NSString *)chainID
                            error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    ISubWallet *subWallet = masterWallet->CreateSubWallet(cchainID);
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Create", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    Json json = subWallet->GetBasicInfo();
    return [self dictWithJson:json];
}

- (NSArray *)getAllSubWalletsWithMasterWalletID:(NSString *)masterWalletID
                                          error:(NSError **)error {

    String cmasterWalletID = [self cstringWithString:masterWalletID];
    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    NSMutableArray *subWalletJsonArray = [[NSMutableArray alloc] init];
    ISubWalletVector subWalletList = masterWallet->GetAllSubWallets();
    for (int i = 0; i < subWalletList.size(); i++) {
        ISubWallet *iSubWallet = subWalletList[i];
        String chainId = iSubWallet->GetChainID();
        NSString *chainIdString = [self stringWithCString:chainId];
        [subWalletJsonArray addObject:chainIdString];
    }

    return subWalletJsonArray;
}

- (void)registerWalletListener:(NSString *)masterWalletID chainID:(NSString *)chainID delegate:(id<ElISubWalletDelegate>)delegate
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID :cchainID];
    if (subWallet == nil) {
        printf("error");
    }
    SPVSubWalletCallback *subCallback = new SPVSubWalletCallback(delegate, cmasterWalletID, cchainID);
    subWallet->AddCallback(subCallback);
}

- (NSString *)getBalance:(NSString *)masterWalletID
                 chainID:(NSString *)chainID
                   error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID :cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    String balance = subWallet->GetBalance();
    return [self stringWithCString:balance];
}

- (NSArray *)getBalanceInfo:(NSString *)masterWalletID
                     chainID:(NSString *)chainID
                       error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = subWallet->GetBalanceInfo();
    return [self arraytWithJson:json];
}

- (NSArray *)getSupportedChains:(NSString *)masterWalletID
                          error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    StringVector stringVec = masterWallet->GetSupportedChains();
    NSMutableArray *stringArray = [[NSMutableArray alloc] init];
    for(int i = 0; i < stringVec.size(); i++) {
        String string = stringVec[i];
        NSString *sstring = [self stringWithCString:string];
        [stringArray addObject:sstring];
    }
    return stringArray;
}

- (NSDictionary *)getMasterWalletBasicInfo:(NSString *)masterWalletID
                                     error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    return [self getBasicInfo:masterWallet];
}

- (NSDictionary *)getAllTransaction:(NSString *)masterWalletID
                            chainID:(NSString *)chainID
                              start:(NSString *)start
                              count:(NSString *)count
                      addressOrTxId:(NSString *)addressOrTxId
                              error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    int    cstart          = [start intValue];
    int    ccount          = [count intValue];
    String caddressOrTxId  = [self cstringWithString:addressOrTxId];
    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID: cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = subWallet->GetAllTransaction(cstart, ccount, caddressOrTxId);
    return [self dictWithJson:json];
}

- (NSString *)createAddress:(NSString *)masterWalletID
                    chainID:(NSString *)chainID
                      error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID :cchainID];
    if (subWallet == NULL) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    String address = subWallet->CreateAddress();
    return [self stringWithCString:address];
}

- (NSString *)getGenesisAddress:(NSString *)masterWalletID
                        chainID:(NSString *)chainID
                          error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    ISidechainSubWallet *sidechainSubWallet = dynamic_cast<ISidechainSubWallet *>(subWallet);
    if(sidechainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of ISidechainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    String address = sidechainSubWallet->GetGenesisAddress();
    return [self stringWithCString:address];
}

- (NSString *)exportWalletWithKeystore:(NSString *)masterWalletID
                        backupPassword:(NSString *)backupPassword
                           payPassword:(NSString *)payPassword
                                 error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cbackupPassword = [self cstringWithString:backupPassword];
    String cpayPassword = [self cstringWithString:payPassword];
    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = masterWallet->ExportKeystore(cbackupPassword, cpayPassword);
    return [self stringWithCString:json.dump()];
}

- (NSString *)exportMnemonicWithmasterWalletID:(NSString *)masterWalletID
                                backupPassword:(NSString *)backupPassword
                                         error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cbackupPassword = [self cstringWithString:backupPassword];
    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = masterWallet->ExportMnemonic(cbackupPassword);
    return [self stringWithCString:json.dump()];
}

- (void)changePassword:(NSString *)masterWalletID
           oldPassword:(NSString *)oldPassword
           newPassword:(NSString *)newPassword
                 error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String coldPassword = [self cstringWithString:oldPassword];
    String cnewPassword = [self cstringWithString:newPassword];
    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    masterWallet->ChangePassword(coldPassword, cnewPassword);
}

- (NSDictionary *)importWalletWithKeystore:(NSString *)masterWalletID
                           keystoreContent:(NSString *)keystoreContent
                            backupPassword:(NSString *)backupPassword
                               payPassword:(NSString *)payPassword
                                     error:(NSError **)error;
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    Json ckeystoreContent = [self jsonWithString:keystoreContent];
    String cbackupPassword = [self cstringWithString:backupPassword];
    String cpayPassword = [self cstringWithString:payPassword];
    IMasterWallet *masterWallet = mMasterWalletManager->ImportWalletWithKeystore(
                                                                                 cmasterWalletID,
                                                                                 ckeystoreContent,
                                                                                 cbackupPassword,
                                                                                 cpayPassword);
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Import", masterWalletID, @"with keystore"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    return [self getBasicInfo:masterWallet];
}

- (NSDictionary *)importWalletWithMnemonic:(NSString *)masterWalletID
                                  mnemonic:(NSString *)mnemonic
                            phrasePassword:(NSString *)phrasePassword
                               payPassword:(NSString *)payPassword
                             singleAddress:(NSString *)singleAddress
                                     error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cmnemonic       = [self cstringWithString:mnemonic];
    String cphrasePassword = [self cstringWithString:phrasePassword];
    String cpayPassword    = [self cstringWithString:payPassword];
    Boolean csingleAddress =  [singleAddress boolValue];

    IMasterWallet *masterWallet = mMasterWalletManager->ImportWalletWithMnemonic(
                                                                                 cmasterWalletID,
                                                                                 cmnemonic,
                                                                                 cphrasePassword,
                                                                                 cpayPassword,
                                                                                 csingleAddress);
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Import", masterWalletID, @"with mnemonic"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    return [self getBasicInfo:masterWallet];
}

- (NSDictionary *)createMultiSignMasterWalletWithMnemonic:(NSString *)masterWalletID
                                                 mnemonic:(NSString *)mnemonic
                                           phrasePassword:(NSString *)phrasePassword
                                              payPassword:(NSString *)payPassword
                                               publicKeys:(NSString *)publicKeys
                                                        m:(NSString *)m
                                                timestamp:(NSString *)timestamp
                                                    error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cmnemonic       = [self cstringWithString:mnemonic];
    String cphrasePassword = [self cstringWithString:phrasePassword];
    String cpayPassword    = [self cstringWithString:payPassword];
    String cstr            = [self cstringWithString:publicKeys];
    Json cpublicKeys       = Json::parse(cstr);
    int cm                 = [m intValue];
    long ctimestamp        = [timestamp longLongValue];

    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    IMasterWallet *masterWallet = mMasterWalletManager->CreateMultiSignMasterWallet(
                                                                                    cmasterWalletID,
                                                                                    cmnemonic,
                                                                                    cphrasePassword,
                                                                                    cpayPassword,
                                                                                    cpublicKeys,
                                                                                    cm,
                                                                                    ctimestamp);
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Create multi sign", masterWalletID, @"with mnemonic"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    return [self getBasicInfo:masterWallet];
}

- (NSDictionary *)createMultiSignMasterWallet:(NSString *)masterWalletID
                                   publicKeys:(NSString *)publicKeys
                                            m:(NSString *)m
                                    timestamp:(NSString *)timestamp
                                        error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String str = [self cstringWithString:publicKeys];
    Json cpublicKeys = Json::parse(str);
    int cm = [m intValue];
    long ctimestamp = [timestamp longLongValue];

    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    IMasterWallet *masterWallet = mMasterWalletManager->CreateMultiSignMasterWallet(
                                                                                    cmasterWalletID,
                                                                                    cpublicKeys,
                                                                                    cm,
                                                                                    ctimestamp);
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Create multi sign", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    return [self getBasicInfo:masterWallet];
}

- (NSDictionary *)createMultiSignMasterWalletWithPrivKey:(NSString *)masterWalletID
                                                 privKey:(NSString *)privKey
                                             payPassword:(NSString *)payPassword
                                              publicKeys:(NSString *)publicKeys
                                                       m:(NSString *)m
                                               timestamp:(NSString *)timestamp
                                                   error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cprivKey        = [self cstringWithString:privKey];
    String cpayPassword    = [self cstringWithString:payPassword];
    String str            = [self cstringWithString:publicKeys];
    Json cpublicKeys       = Json::parse(str);
    int cm                 = [m intValue];
    long ctimestamp        = [timestamp longLongValue];
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    IMasterWallet *masterWallet = mMasterWalletManager->CreateMultiSignMasterWallet(
                                                                                    cmasterWalletID,
                                                                                    cprivKey,
                                                                                    cpayPassword,
                                                                                    cpublicKeys,
                                                                                    cm,
                                                                                    ctimestamp);
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Create multi sign", masterWalletID, @"with private key"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    return [self getBasicInfo:masterWallet];
}

- (NSString *)getAllAddress:(NSString *)masterWalletID
                    chainID:(NSString *)chainID
                      start:(NSString *)start
                      count:(NSString *)count
                      error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    int cstart             = [start intValue];
    int ccount             = [count intValue];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = subWallet->GetAllAddress(cstart, ccount);
    return [self stringWithCString:json.dump()];
}

// new
- (NSString *)getAllPublicKeys:(NSString *)masterWalletID
                       chainID:(NSString *)chainID
                         start:(NSString *)start
                         count:(NSString *)count
                         error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    int cstart             = [start intValue];
    int ccount             = [count intValue];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = subWallet->GetAllPublicKeys(cstart, ccount);
    NSString *jsonString = [self stringWithCString:json.dump()];
    return jsonString;
}

- (BOOL)isAddressValid:(NSString *)masterWalletID
                  addr:(NSString *)addr
                 error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String caddr       = [self cstringWithString:addr];

    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Boolean valid = masterWallet->IsAddressValid(caddr);
    return valid;
}

- (NSString *)createDepositTransaction:(NSString *)masterWalletID
                               chainID:(NSString *)chainID
                           fromAddress:(NSString *)fromAddress
                         lockedAddress:(NSString *)lockedAddress
                                amount:(NSString *)amount
                      sideChainAddress:(NSString *)sideChainAddress
                                  memo:(NSString *)memo
                                 error:(NSError **)error
{
    String cmasterWalletID    = [self cstringWithString:masterWalletID];
    String cchainID           = [self cstringWithString:chainID];
    String cfromAddress       = [self cstringWithString:fromAddress];
    String clockedAddress     = [self cstringWithString:lockedAddress];
    String camount            = [self cstringWithString:amount];
    String csideChainAddress  = [self cstringWithString:sideChainAddress];
    String cmemo              = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = mainchainSubWallet->CreateDepositTransaction(cfromAddress,
                                                             clockedAddress,
                                                             camount,
                                                             csideChainAddress,
                                                             cmemo);
    return [self stringWithCString:json.dump()];
}

- (NSString *)destroyWallet:(NSString *)masterWalletID
                      error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];

    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    ISubWalletVector subWallets = masterWallet->GetAllSubWallets();
    for (int i = 0; i < subWallets.size(); i++) {
        subWallets[i]->RemoveCallback();
    }

    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"Master wallet manager has not initialize"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    mMasterWalletManager->DestroyWallet(cmasterWalletID);
    return [NSString stringWithFormat:@"Destroy %@ OK", masterWalletID];
}

- (NSString *)createTransaction:(NSString *)masterWalletID
                        chainID:(NSString *)chainID
                    fromAddress:(NSString *)fromAddress
                      toAddress:(NSString *)toAddress
                         amount:(NSString *)amount
                           memo:(NSString *)memo
                          error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cfromAddress    = [self cstringWithString:fromAddress];
    String ctoAddress      = [self cstringWithString:toAddress];
    String camount         = [self cstringWithString:amount];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = subWallet->CreateTransaction(cfromAddress,
                                             ctoAddress,
                                             camount,
                                             cmemo);
    return [self stringWithJson:json];
}

- (NSString *)getAllUTXOs:(NSString *)masterWalletID
                  chainID:(NSString *)chainID
                    start:(NSString *)start
                    count:(NSString *)count
                  address:(NSString *)address
                    error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    int cstart             = [start intValue];
    int ccount             = [count intValue];
    String caddress        = [self cstringWithString:address];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json result = subWallet->GetAllUTXOs(cstart, ccount, caddress);
    return [self stringWithJson:result];
}

- (NSString *)createConsolidateTransaction:(NSString *)masterWalletID
                                   chainID:(NSString *)chainID
                                      memo:(NSString *)memo
                                     error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json result = subWallet->CreateConsolidateTransaction(cmemo);
    return [self stringWithJson:result];
}

- (NSString *)signTransaction:(NSString *)masterWalletID
                      chainID:(NSString *)chainID
               rawTransaction:(NSString *)rawTransaction
                  payPassword:(NSString *)payPassword
                        error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    Json crawTransaction   = [self jsonWithString:rawTransaction];
    String cpayPassword    = [self cstringWithString:payPassword];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json result = subWallet->SignTransaction(crawTransaction, cpayPassword);
    return [self stringWithJson:result];
}

- (NSString *)publishTransaction:(NSString *)masterWalletID
                         chainID:(NSString *)chainID
                       rawTxJson:(NSString *)rawTxJson
                           error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    Json crawTxJson        =  [self jsonWithString:rawTxJson];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json result = subWallet->PublishTransaction(crawTxJson);
    return [self stringWithJson:result];
}

//- (void)saveConfigs
//{
//    if(mMasterWalletManager)
//    {
//        mMasterWalletManager->SaveConfigs();
//    }
//}

- (NSDictionary *)importWalletWithOldKeystore:(NSString *)masterWalletID
                              keystoreContent:(NSString *)keystoreContent
                               backupPassword:(NSString *)backupPassword
                                  payPassword:(NSString *)payPassword
                               phrasePassword:(NSString *)phrasePassword
                                        error:(NSError **)error
{
    String cmasterWalletID  = [self cstringWithString:masterWalletID];
    String ckeystoreContent = [self cstringWithString:keystoreContent];
    String cbackupPassword  = [self cstringWithString:backupPassword];
    String cpayPassword     = [self cstringWithString:payPassword];
    String cphrasePassword  = [self cstringWithString:phrasePassword];

    IMasterWallet *masterWallet = mMasterWalletManager->ImportWalletWithKeystore(
                                                                                 cmasterWalletID,
                                                                                 ckeystoreContent,
                                                                                 cbackupPassword,
                                                                                 cpayPassword);
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"Import", masterWalletID, @"with keystore"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    return [self getBasicInfo:masterWallet];
}

- (NSString *)getTransactionSignedSigners:(NSString *)masterWalletID
                                  chainID:(NSString *)chainID
                                rawTxJson:(NSString *)rawTxJson
                                    error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    Json crawTxJson        = [self jsonWithString:rawTxJson];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    Json resultJson = subWallet->GetTransactionSignedInfo(crawTxJson);
    return [self stringWithJson:resultJson];
}

- (void)removeWalletListener:(NSString *)masterWalletID
                     chainID:(NSString *)chainID
                       error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    subWallet->RemoveCallback();
}

- (NSString *)createIdTransaction:(NSString *)masterWalletID
                          chainID:(NSString *)chainID
                      payloadJson:(NSDictionary *)payloadJson
                             memo:(NSString *)memo
                            error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    Json cpayloadJson      = [self jsonWithDict:payloadJson];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IIDChainSubWallet *idchainSubWallet = dynamic_cast<IIDChainSubWallet *>(subWallet);
    if(idchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IIDChainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    Json json = idchainSubWallet->CreateIDTransaction(cpayloadJson, cmemo);
    return [self stringWithJson:json];
}

- (NSString *)createWithdrawTransaction:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                            fromAddress:(NSString *)fromAddress
                                 amount:(NSString *)amount
                       mainchainAddress:(NSString *)mainchainAddress
                                   memo:(NSString *)memo
                                  error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cfromAddress    = [self cstringWithString:fromAddress];
    String camount         = [self cstringWithString:amount];
    String cmainchainAddress  = [self cstringWithString:mainchainAddress];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    ISidechainSubWallet *sidechainSubWallet = dynamic_cast<ISidechainSubWallet *>(subWallet);
    if(sidechainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of ISidechainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = sidechainSubWallet->CreateWithdrawTransaction(cfromAddress,
                                                              camount,
                                                              cmainchainAddress,
                                                              cmemo);
    return [self stringWithJson:json];
}

- (NSDictionary *)getMasterWallet:(NSString *)masterWalletID
                            error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];;

    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    return [self getBasicInfo:masterWallet];
}

- (void)destroySubWallet:(NSString *)masterWalletID
                 chainID:(NSString *)chainID
                   error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];

    IMasterWallet *masterWallet = [self getIMasterWallet:cmasterWalletID];
    if (masterWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    masterWallet->DestroyWallet(cchainID);
    subWallet->RemoveCallback();
}

- (NSString *)getVersionWithError:(NSError **)error
{
    if (mMasterWalletManager == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", @"Master wallet manager has not initialize"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    String version = mMasterWalletManager->GetVersion();
    NSString *msg = [self stringWithCString:version];
    return msg;
}

- (NSString *)generateProducerPayload:(NSString *)masterWalletID
                              chainID:(NSString *)chainID
                            publicKey:(NSString *)publicKey
                        nodePublicKey:(NSString *)nodePublicKey
                             nickName:(NSString *)nickName
                                  url:(NSString *)url
                            IPAddress:(NSString *)IPAddress
                             location:(NSString *)location
                            payPasswd:(NSString *)payPasswd
                                error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cpublicKey      = [self cstringWithString:publicKey];
    String cnodePublicKey  = [self cstringWithString:nodePublicKey];
    String cnickName       = [self cstringWithString:nickName];
    String curl            = [self cstringWithString:url];
    String cIPAddress      = [self cstringWithString:IPAddress];
    long   clocation       = [location longLongValue];
    String cpayPasswd      = [self cstringWithString:payPasswd];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    Json payloadJson = mainchainSubWallet->GenerateProducerPayload(cpublicKey,
                                                                   cnodePublicKey,
                                                                   cnickName,
                                                                   curl,
                                                                   cIPAddress,
                                                                   clocation,
                                                                   cpayPasswd);
    return [self stringWithJson:payloadJson];
}

- (NSString *)generateCancelProducerPayload:(NSString *)masterWalletID
                                    chainID:(NSString *)chainID
                                  publicKey:(NSString *)publicKey
                                  payPasswd:(NSString *)payPasswd
                                      error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cpublicKey      = [self cstringWithString:publicKey];
    String cpayPasswd      = [self cstringWithString:payPasswd];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    String payloadJson = mainchainSubWallet->GenerateCancelProducerPayload(cpublicKey, cpayPasswd);
    return [self stringWithJson:payloadJson];
}

- (NSString *)createRegisterProducerTransaction:(NSString *)masterWalletID
                                        chainID:(NSString *)chainID
                                    fromAddress:(NSString *)fromAddress
                                    payloadJson:(NSString *)payloadJson
                                         amount:(NSString *)amount
                                           memo:(NSString *)memo
                                          error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cfromAddress    = [self cstringWithString:fromAddress];
    Json cpayloadJson      = [self jsonWithString:payloadJson];
    String camount         = [self cstringWithString:amount];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson = mainchainSubWallet->CreateRegisterProducerTransaction(cfromAddress,
                                                                        cpayloadJson,
                                                                        camount,
                                                                        cmemo);
    return [self stringWithJson:txJson];
}

- (NSString *)createUpdateProducerTransaction:(NSString *)masterWalletID
                                      chainID:(NSString *)chainID
                                  fromAddress:(NSString *)fromAddress
                                  payloadJson:(NSString *)payloadJson
                                         memo:(NSString *)memo
                                        error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cfromAddress    = [self cstringWithString:fromAddress];
    Json cpayloadJson      = [self jsonWithString:payloadJson];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson = mainchainSubWallet->CreateUpdateProducerTransaction(cfromAddress, cpayloadJson, cmemo);
    return [self stringWithJson:txJson];
}

- (NSString *)createCancelProducerTransaction:(NSString *)masterWalletID
                                      chainID:(NSString *)chainID
                                  fromAddress:(NSString *)fromAddress
                                  payloadJson:(NSString *)payloadJson
                                         memo:(NSString *)memo
                                        error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cfromAddress    = [self cstringWithString:fromAddress];
    Json cpayloadJson      = [self jsonWithString:payloadJson];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet",masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson =  mainchainSubWallet->CreateCancelProducerTransaction(cfromAddress, cpayloadJson, cmemo);
    return [self stringWithJson:txJson];
}

- (NSString *)createRetrieveDepositTransaction:(NSString *)masterWalletID
                                       chainID:(NSString *)chainID
                                        amount:(NSString *)amount
                                          memo:(NSString *)memo
                                         error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String camount         = [self cstringWithString:amount];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson =  mainchainSubWallet->CreateRetrieveDepositTransaction(camount, cmemo);
    return [self stringWithJson:txJson];
}

- (NSString *)getOwnerPublicKey:(NSString *)masterWalletID
                        chainID:(NSString *)chainID
                          error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    String msg = mainchainSubWallet->GetOwnerPublicKey();
    return [self stringWithCString:msg];
}

- (NSString *)createVoteProducerTransaction:(NSString *)masterWalletID
                                    chainID:(NSString *)chainID
                                fromAddress:(NSString *)fromAddress
                                      stake:(NSString *)stake
                                 publicKeys:(NSString *)publicKeys
                                       memo:(NSString *)memo
                                      error:(NSError **)error
{
    String cmasterWalletID  = [self cstringWithString:masterWalletID];
    String cchainID         = [self cstringWithString:chainID];
    String cfromAddress     = [self cstringWithString:fromAddress];
    String cstake           = [self cstringWithString:stake];
    Json cpublicKeys        = [self jsonWithString:publicKeys];
    String cmemo            = [self cstringWithString:memo];
    Json invalidCandidates = Json::parse("[]");

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson = mainchainSubWallet->CreateVoteProducerTransaction(cfromAddress,
                                                                    cstake,
                                                                    cpublicKeys,
                                                                    cmemo,
                                                                    invalidCandidates);
    return [self stringWithJson:txJson];
}

- (NSString *)getVotedProducerList:(NSString *)masterWalletID
                           chainID:(NSString *)chainID
                             error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID :cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = mainchainSubWallet->GetVotedProducerList();
    return [self stringWithJson:json];
}

- (NSString *)getRegisteredProducerInfo:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                                  error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID :cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = mainchainSubWallet->GetRegisteredProducerInfo();
    return [self stringWithJson:json];
}

// CR
- (NSString *)generateCRInfoPayload:(NSString *)masterWalletID
                            chainID:(NSString *)chainID
                        crPublicKey:(NSString *)crPublicKey
                                did:(NSString *)did
                           nickName:(NSString *)nickName
                                url:(NSString *)url
                           location:(NSString *)location
                              error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String ccrPublicKey    = [self cstringWithString:crPublicKey];
    String cdid            = [self cstringWithString:did];
    String cnickName       = [self cstringWithString:nickName];
    String curl            = [self cstringWithString:url];
    long   clocation       = [location longLongValue];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID :cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    //TODO: upgrade spv sdk
    //    Json payloadJson = mainchainSubWallet->GenerateCRInfoPayload(crPublicKey, did, nickName, url, location);
    Json payloadJson = mainchainSubWallet->GenerateCRInfoPayload(ccrPublicKey, cnickName, curl, clocation);
    return [self stringWithJson:payloadJson];
}

- (NSString *)generateUnregisterCRPayload:(NSString *)masterWalletID
                                  chainID:(NSString *)chainID
                                      did:(NSString *)did
                                    error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cdid            = [self cstringWithString:did];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    Json payloadJson = mainchainSubWallet->GenerateUnregisterCRPayload(cdid);
    return [self stringWithJson:payloadJson];
}

- (NSString *)createRegisterCRTransaction:(NSString *)masterWalletID
                                  chainID:(NSString *)chainID
                              fromAddress:(NSString *)fromAddress
                              payloadJson:(NSString *)payloadJson
                                   amount:(NSString *)amount
                                     memo:(NSString *)memo
                                    error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cfromAddress    = [self cstringWithString:fromAddress];
    Json cpayloadJson      = [self jsonWithString:payloadJson];
    String camount         = [self cstringWithString:amount];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    Json txJson = mainchainSubWallet->CreateRegisterCRTransaction(cfromAddress, cpayloadJson, camount, cmemo);
    return [self stringWithJson:txJson];
}

- (NSString *)createUpdateCRTransaction:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                            fromAddress:(NSString *)fromAddress
                            payloadJson:(NSString *)payloadJson
                                   memo:(NSString *)memo
                                  error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cfromAddress    = [self cstringWithString:fromAddress];
    Json cpayloadJson      = [self jsonWithString:payloadJson];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID,chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson = mainchainSubWallet->CreateUpdateCRTransaction(cfromAddress, cpayloadJson, cmemo);
    return [self stringWithJson:txJson];
}

- (NSString *)createUnregisterCRTransaction:(NSString *)masterWalletID
                                    chainID:(NSString *)chainID
                                fromAddress:(NSString *)fromAddress
                                payloadJson:(NSString *)payloadJson
                                       memo:(NSString *)memo
                                      error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String cfromAddress    = [self cstringWithString:fromAddress];
    Json cpayloadJson      = [self jsonWithString:payloadJson];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson =  mainchainSubWallet->CreateUnregisterCRTransaction(cfromAddress, cpayloadJson, cmemo);
    return [self stringWithJson:txJson];
}

- (NSString *)createRetrieveCRDepositTransaction:(NSString *)masterWalletID
                                         chainID:(NSString *)chainID
                                     crPublicKey:(NSString *)crPublicKey
                                          amount:(NSString *)amount
                                            memo:(NSString *)memo
                                           error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];
    String ccrPublicKey    = [self cstringWithString:crPublicKey];
    String camount         = [self cstringWithString:amount];
    String cmemo           = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson =  mainchainSubWallet->CreateRetrieveCRDepositTransaction(ccrPublicKey, camount, cmemo);
    return [self stringWithJson:txJson];
}

- (NSString *)createVoteCRTransaction:(NSString *)masterWalletID
                              chainID:(NSString *)chainID
                          fromAddress:(NSString *)fromAddress
                           publicKeys:(NSDictionary *)publicKeys
                                 memo:(NSString *)memo
                    invalidCandidates:(NSString *)invalidCandidates
                                error:(NSError **)error
{
    String cmasterWalletID  = [self cstringWithString:masterWalletID];
    String cchainID         = [self cstringWithString:chainID];
    String cfromAddress     = [self cstringWithString:fromAddress];
    Json cpublicKeys        = [self jsonWithDict:publicKeys];
    String cmemo            = [self cstringWithString:memo];
    Json cinvalidCandidates = [self jsonWithString:invalidCandidates];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson = mainchainSubWallet->CreateVoteCRTransaction(cfromAddress, cpublicKeys, cmemo, cinvalidCandidates);
    return [self stringWithJson:txJson];
}

- (NSString *)getVotedCRList:(NSString *)masterWalletID
                     chainID:(NSString *)chainID
                       error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = mainchainSubWallet->GetVotedCRList();
    return [self stringWithJson:json];
}

- (NSString *)getRegisteredCRInfo:(NSString *)masterWalletID
                          chainID:(NSString *)chainID
                            error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID        = [self cstringWithString:chainID];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = mainchainSubWallet->GetRegisteredCRInfo();
    return [self stringWithJson:json];
}

- (NSString *)getVoteInfo:(NSString *)masterWalletID
                  chainID:(NSString *)chainID
                     type:(NSString *)type
                    error:(NSError **)error
{
    String cmasterWalletID  = [self cstringWithString:masterWalletID];
    String cchainID         = [self cstringWithString:chainID];
    String ctype            = [self cstringWithString:type];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json txJson = mainchainSubWallet->GetVoteInfo(ctype);
    return [self stringWithJson:txJson];
}

- (NSString *)sponsorProposalDigest:(NSString *)masterWalletID
                            chainID:(NSString *)chainID
                               type:(NSString *)type
                       categoryData:(NSString *)categoryData
                   sponsorPublicKey:(NSString *)sponsorPublicKey
                          draftHash:(NSString *)draftHash
                            budgets:(NSString *)budgets
                          recipient:(NSString *)recipient
                              error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    int ctype                = [type intValue];
    String ccategoryData     = [self cstringWithString:categoryData];
    String csponsorPublicKey = [self cstringWithString:sponsorPublicKey];
    String cdraftHash        = [self cstringWithString:draftHash];
    Json cbudgets            = [self jsonWithString:budgets];
    String crecipient        = [self cstringWithString:recipient];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    //  TODO upgrade spv sdk
    //    Json stringJson = mainchainSubWallet->SponsorProposalDigest(type, categoryData, sponsorPublicKey,
    //            draftHash, budgets, recipient);
    Json stringJson = mainchainSubWallet->SponsorProposalDigest(ctype, csponsorPublicKey, cdraftHash, cbudgets, crecipient);
    return [self stringWithJson:stringJson];
}

- (NSString *)CRSponsorProposalDigest:(NSString *)masterWalletID
                              chainID:(NSString *)chainID
                sponsorSignedProposal:(NSString *)sponsorSignedProposal
                         crSponsorDID:(NSString *)crSponsorDID
                        crOpinionHash:(NSString *)crOpinionHash
                                error:(NSError **)error
{
    String cmasterWalletID       = [self cstringWithString:masterWalletID];
    String cchainID              = [self cstringWithString:chainID];
    Json csponsorSignedProposal  = [self jsonWithString:sponsorSignedProposal];
    String ccrSponsorDID         = [self cstringWithString:crSponsorDID];
    String ccrOpinionHash        = [self cstringWithString:crOpinionHash];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@  is not instance of IMainchainSubWallet", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->CRSponsorProposalDigest(csponsorSignedProposal, ccrSponsorDID);
    return [self stringWithJson:stringJson];
}

- (NSString *)createCRCProposalTransaction:(NSString *)masterWalletID
                                   chainID:(NSString *)chainID
                          crSignedProposal:(NSString *)crSignedProposal
                                      memo:(NSString *)memo
                                     error:(NSError **)error
{

    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    Json ccrSignedProposal   = [self jsonWithString:crSignedProposal];
    String cmemo             = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->CreateCRCProposalTransaction(ccrSignedProposal, cmemo);
    return [self stringWithJson:stringJson];
}

- (NSString *)generateCRCProposalReview:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                           proposalHash:(NSString *)proposalHash
                             voteResult:(NSString *)voteResult
                                    did:(NSString *)did
                                  error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    String cproposalHash     = [self cstringWithString:proposalHash];
    int cvoteResult          = [voteResult intValue];
    String cdid              = [self cstringWithString:did];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->GenerateCRCProposalReview(cproposalHash, cvoteResult, cdid);
    return [self stringWithJson:stringJson];
}

- (NSString *)createCRCProposalReviewTransaction:(NSString *)masterWalletID
                                         chainID:(NSString *)chainID
                                  proposalReview:(NSString *)proposalReview
                                            memo:(NSString *)memo
                                           error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    Json cproposalReview     = [self jsonWithString:proposalReview];
    String cmemo             = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->CreateCRCProposalReviewTransaction(cproposalReview, cmemo);
    return [self stringWithJson:stringJson];
}

- (NSString *)createVoteCRCProposalTransaction:(NSString *)masterWalletID
                                       chainID:(NSString *)chainID
                                   fromAddress:(NSString *)fromAddress
                                         votes:(NSString *)votes
                                          memo:(NSString *)memo
                             invalidCandidates:(NSString *)invalidCandidates
                                         error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    String cfromAddress      = [self cstringWithString:fromAddress];
    Json cvotes              = [self jsonWithString:votes];
    String cmemo             = [self cstringWithString:memo];
    Json cinvalidCandidates  = [self jsonWithString:invalidCandidates];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->CreateVoteCRCProposalTransaction(cfromAddress, cvotes, cmemo, cinvalidCandidates);
    return [self stringWithJson:stringJson];
}

- (NSString *)createImpeachmentCRCTransaction:(NSString *)masterWalletID
                                      chainID:(NSString *)chainID
                                  fromAddress:(NSString *)fromAddress
                                        votes:(NSString *)votes
                                         memo:(NSString *)memo
                            invalidCandidates:(NSString *)invalidCandidates
                                        error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    String cfromAddress      = [self cstringWithString:fromAddress];
    Json cvotes              = [self jsonWithString:votes];
    String cmemo             = [self cstringWithString:memo];
    Json cinvalidCandidates  = [self jsonWithString:invalidCandidates];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->CreateImpeachmentCRCTransaction(cfromAddress, cvotes, cmemo, cinvalidCandidates);
    return [self stringWithJson:stringJson];
}

- (NSString *)leaderProposalTrackDigest:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                                   type:(NSString *)type
                           proposalHash:(NSString *)proposalHash
                           documentHash:(NSString *)documentHash
                                  stage:(NSString *)stage
                          appropriation:(NSString *)appropriation
                           leaderPubKey:(NSString *)leaderPubKey
                        newLeaderPubKey:(NSString *)newLeaderPubKey
                                  error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    int ctype                = [type intValue];
    String cproposalHash     = [self cstringWithString:proposalHash];
    String cdocumentHash     = [self cstringWithString:documentHash];
    int cstage               = [stage intValue];
    String cappropriation    = [self cstringWithString:appropriation];
    String cleaderPubKey     = [self cstringWithString:leaderPubKey];
    String cnewLeaderPubKey  = [self cstringWithString:newLeaderPubKey];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->LeaderProposalTrackDigest(ctype,
                                                                    cproposalHash,
                                                                    cdocumentHash,
                                                                    cstage,
                                                                    cappropriation,
                                                                    cleaderPubKey,
                                                                    cnewLeaderPubKey);
    return [self stringWithJson:stringJson];
}

- (NSString *)newLeaderProposalTrackDigest:(NSString *)masterWalletID
                                   chainID:(NSString *)chainID
              leaderSignedProposalTracking:(NSString *)leaderSignedProposalTracking
                                     error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    Json cleaderSignedProposalTracking = [self jsonWithString:leaderSignedProposalTracking];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->NewLeaderProposalTrackDigest(cleaderSignedProposalTracking);
    return [self stringWithJson:stringJson];
}

- (NSString *)secretaryGeneralProposalTrackDigest:(NSString *)masterWalletID
                                          chainID:(NSString *)chainID
                     leaderSignedProposalTracking:(NSString *)leaderSignedProposalTracking
                                            error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    Json cleaderSignedProposalTracking = [self jsonWithString:leaderSignedProposalTracking];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->SecretaryGeneralProposalTrackDigest(cleaderSignedProposalTracking);
    return [self stringWithJson:stringJson];
}

- (NSString *)createProposalTrackingTransaction:(NSString *)masterWalletID
                                        chainID:(NSString *)chainID
                  SecretaryGeneralSignedPayload:(NSString *)SecretaryGeneralSignedPayload
                                           memo:(NSString *)memo
                                          error:(NSError **)error
{
    String cmasterWalletID   = [self cstringWithString:masterWalletID];
    String cchainID          = [self cstringWithString:chainID];
    Json cSecretaryGeneralSignedPayload = [self jsonWithString:SecretaryGeneralSignedPayload];
    String cmemo             = [self cstringWithString:memo];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }
    IMainchainSubWallet *mainchainSubWallet = dynamic_cast<IMainchainSubWallet *>(subWallet);
    if(mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", masterWalletID, chainID, @" is not instance of IMainchainSubWallet"];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json stringJson = mainchainSubWallet->CreateProposalTrackingTransaction(cSecretaryGeneralSignedPayload, cmemo);
    return [self stringWithJson:stringJson];
}

- (NSString *)syncStartMasterWalletID:(NSString *)masterWalletID
                        chainID:(NSString *)chainID
                          error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID       = [self cstringWithString:chainID];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    subWallet->SyncStart();
    return @"sync Start OK";
}

- (void)syncStop:(NSString *)masterWalletID
         chainID:(NSString *)chainID
           error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cchainID       = [self cstringWithString:chainID];

    ISubWallet *subWallet = [self getSubWallet:cmasterWalletID:cchainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@ Get", masterWalletID, chainID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    subWallet->SyncStop();;
}

String const IDChain = "IDChain";

- (IIDChainSubWallet*) getIDChainSubWallet:(String)masterWalletID {
    ISubWallet* subWallet = [self getSubWallet:masterWalletID :IDChain];

    return dynamic_cast<IIDChainSubWallet *>(subWallet);
}

- (NSString *)getResolveDIDInfo:(NSString *)masterWalletID
                          start:(NSString *)start
                          count:(NSString *)count
                            did:(NSString *)did
                          error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    int cstart = [start intValue];
    int ccount = [count intValue];
    String cdid            = [self cstringWithString:did];

    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:cmasterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = idChainSubWallet->GetResolveDIDInfo(cstart, ccount, cdid);
    return [self stringWithJson:json];
}

- (NSString *)getAllDID:(NSString *)masterWalletID
                  start:(NSString *)start
                  count:(NSString *)count
                  error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    int cstart = [start intValue];
    int ccount = [count intValue];

    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:cmasterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Json json = idChainSubWallet->GetAllDID(cstart, ccount);
    return [self stringWithJson:json];
}

- (NSString *)didSign:(NSString *)masterWalletID
                  did:(NSString *)did
              message:(NSString *)message
          payPassword:(NSString *)payPassword
                error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cdid            = [self cstringWithString:did];
    String cmessage        = [self cstringWithString:message];
    String cpayPassword    = [self cstringWithString:payPassword];

    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:cmasterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    String ret = idChainSubWallet->Sign(cdid, cmessage, cpayPassword);
    return [self stringWithJson:ret];
}

- (NSString *)didSignDigest:(NSString *)masterWalletID
                        did:(NSString *)did
                     digest:(NSString *)digest
                payPassword:(NSString *)payPassword
                      error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cdid            = [self cstringWithString:did];
    String cdigest        = [self cstringWithString:digest];
    String cpayPassword    = [self cstringWithString:payPassword];

    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:cmasterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    String ret = idChainSubWallet->SignDigest(cdid, cdigest, cpayPassword);
    return [self stringWithJson:ret];
}

- (BOOL)verifySignature:(NSString *)masterWalletID
              publicKey:(NSString *)publicKey
                message:(NSString *)message
              signature:(NSString *)signature
                  error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cpublicKey            = [self cstringWithString:publicKey];
    String cmessage        = [self cstringWithString:message];
    String csignature    = [self cstringWithString:signature];

    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:cmasterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    Boolean ret = idChainSubWallet->VerifySignature(cpublicKey, cmessage, csignature);
    return ret;
}

- (NSString *)getPublicKeyDID:(NSString *)masterWalletID
                    publicKey:(NSString *)publicKey
                        error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cpublicKey            = [self cstringWithString:publicKey];

    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:cmasterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    String ret = idChainSubWallet->GetPublicKeyDID(cpublicKey);
    return [self stringWithJson:ret];
}

- (NSString *)generateDIDInfoPayload:(NSString *)masterWalletID
                             didInfo:(NSString *)didInfo
                           paypasswd:(NSString *)paypasswd
                               error:(NSError **)error
{
    String cmasterWalletID = [self cstringWithString:masterWalletID];
    String cdidInfo        = [self cstringWithString:didInfo];
    String cpaypasswd      = [self cstringWithString:paypasswd];

    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:cmasterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", masterWalletID];
        NSDictionary *userInfo = @{@"info": msg};
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:errCodeCreateMasterWallet userInfo:userInfo];
        }
    }

    String ret = idChainSubWallet->GenerateDIDInfoPayload(cdidInfo, cpaypasswd);
    return [self stringWithJson:ret];
}

@end
