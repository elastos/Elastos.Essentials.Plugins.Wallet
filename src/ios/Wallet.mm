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
#import <Cordova/CDVCommandDelegate.h>

#pragma mark - ElISubWalletCallback C++

using namespace Elastos::ElaWallet;

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

- (IEthSidechainSubWallet*) getEthSidechainSubWallet:(String)masterWalletID :(String)chainID
{
    ISubWallet* subWallet = [self getSubWallet:masterWalletID :chainID];

    return dynamic_cast<IEthSidechainSubWallet *>(subWallet);
}

- (IElastosBaseSubWallet*) getElastosBaseSubWallet:(String)masterWalletID :(String)chainID
{
    ISubWallet* subWallet = [self getSubWallet:masterWalletID :chainID];

    return dynamic_cast<IElastosBaseSubWallet *>(subWallet);
}

- (IBTCSubWallet*) getBTCSubWallet:(String)masterWalletID
{
    ISubWallet* subWallet = [self getSubWallet:masterWalletID :"BTC"];

    return dynamic_cast<IBTCSubWallet *>(subWallet);
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

- (void)exceptionProcess:(CDVInvokedUrlCommand *)command  string:(String) exceptionString msg:(String) msg
{
    NSString *errString=[self stringWithCString:exceptionString];
    NSDictionary *dic=  [self dictionaryWithJsonString:errString];
    if (dic != nil) {
        NSString *msgStr =  [NSString stringWithFormat:@"%@: %@", [self stringWithCString:msg], dic[@"Message"]];
        [self errorProcess:command code:[dic[@"Code"] intValue] msg:msgStr];
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

    TAG = @"Wallet";

    walletRefCount++;

    keySuccess   = @"success";
    keyError     = @"error";
    keyCode      = @"code";
    keyMessage   = @"message";
    keyException = @"exception";
    listenerCallbackId = @"";

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

    [super pluginInitialize];
}


- (void)dispose
{
    walletRefCount--;

    if (mMasterWalletManager != nil) {
        if (0 == walletRefCount) {
            [self destroyMasterWalletManager];
        }
    }

    [super dispose];
}

- (void)destroyMasterWalletManager
{
    if (mMasterWalletManager != nil) {
        try {
            dispatch_semaphore_wait(walletSemaphore, DISPATCH_TIME_FOREVER);

            // TODO: crash in spvsdk sometimes
            //  delete mMasterWalletManager;
            mMasterWalletManager = nil;
        } catch (const std:: exception &e) {
            NSLog(@"wallet plugin dispose error: %s", e.what());
        }

        dispatch_semaphore_signal(walletSemaphore);
    }
}

- (void)init:(CDVInvokedUrlCommand *)command
{
    if (nil != mMasterWalletManager) {
        return [self successAsString:command msg:@""];
    }

    int idx = 0;
    NSArray *args = command.arguments;

    String dir = [self cstringWithString:[args objectAtIndex:idx++]];
    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    // TODO:check the did
    if (dir.length() == 0) {
        return [self exceptionProcess:command string:"Invalid dir" msg:""];
    }

    NSString *rootPath = [NSString stringWithFormat:@"%s", dir.c_str()];
    if (dir.c_str()[0] != '/') {
        rootPath = [NSString stringWithFormat:@"%@/Documents/spv/%s", NSHomeDirectory(), dir.c_str()];
    }
    rootPath = [rootPath stringByAppendingString:@"/spv"];

    s_dataRootPath = [rootPath stringByAppendingString:@"/data/"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:s_dataRootPath]) {
        [fm createDirectoryAtPath:s_dataRootPath withIntermediateDirectories:true attributes:NULL error:NULL];
    }

    try {
        nlohmann::json config;
        if (s_netConfig && s_netConfig.length > 0) {
            config = nlohmann::json::parse([s_netConfig UTF8String]);
        }
        NSLog(@"WALLETTEST new MasterWalletManager rootPath: %@,  dataPath:%@", rootPath, s_dataRootPath);
        mMasterWalletManager = new MasterWalletManager([rootPath UTF8String], [s_netType UTF8String],
                                                       config, [s_dataRootPath UTF8String]);
        mMasterWalletManager->SetLogLevel(s_logLevel);

        walletSemaphore = dispatch_semaphore_create(1);

        return [self successAsString:command msg:@""];
    } catch (const std:: exception & e ) {
        NSString *errString=[self stringWithCString:e.what()];
        NSLog(@"init MasterWalletManager error: %@", errString);
        String msg = "create master wallet";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)destroy:(CDVInvokedUrlCommand *)command
{
    try {
        [self destroyMasterWalletManager];
        return [self successAsString:command msg:@""];
    } catch (const std:: exception &e) {
        return [self exceptionProcess:command string:e.what() msg:"destroy "];
    }
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
        String msg = "get All MasterWallets";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = "create masterWallet";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createMasterWalletWithPrivKey:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *array = command.arguments;

    String masterWalletID   = [self cstringWithString:[array objectAtIndex:idx++]];
    String singlePrivateKey = [self cstringWithString:[array objectAtIndex:idx++]];
    String payPassword      = [self cstringWithString:[array objectAtIndex:idx++]];

    NSArray *args = command.arguments;
    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    try {
        IMasterWallet *masterWallet = mMasterWalletManager->CreateMasterWallet(
                masterWalletID, singlePrivateKey, payPassword);

        if (masterWallet == NULL) {
            NSString *msg = [NSString stringWithFormat:@"createMasterWalletWithPrivKey %@", [self formatWalletName:masterWalletID]];
            return [self errorProcess:command code:errCodeCreateMasterWallet msg:msg];
        }

        NSString *jsonString = [self getBasicInfo:masterWallet];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = "create masterWallet With Private Key";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = "generate mnemonic";
        return [self exceptionProcess:command string:e.what() msg:msg];
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

        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = "create subWallet " + masterWalletID + ":" + chainID;
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + " get All SubWallets ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + " get supported chains ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + " export wallet with keystore ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + " export wallet with mnemonic ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)exportWalletWithSeed:(CDVInvokedUrlCommand *)command
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
        Json json = masterWallet->ExportSeed(backupPassword);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + " export wallet with seed ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)exportWalletWithPrivateKey:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
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
        Json json = masterWallet->ExportPrivateKey(payPassword);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + " export wallet with private key ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + " verify passphrase ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + " verify password ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + " change password ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        Json json = masterWallet->GetPubKeyInfo();
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + " get pubkey info ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = "import wallet with keystore ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = "import wallet with mnemonic ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)importWalletWithSeed:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String seed           = [self cstringWithString:args[idx++]];
    String payPassword    = [self cstringWithString:args[idx++]];
    Boolean singleAddress = [args[idx++] boolValue];
    String mnemonic       = [self cstringWithString:args[idx++]];
    String phrasePassword = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    try {
        IMasterWallet *masterWallet = mMasterWalletManager->ImportWalletWithSeed(
                masterWalletID, seed, payPassword, singleAddress, mnemonic, phrasePassword);
        if (masterWallet == nil) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@ %@", @"ImportWalletWithSeed", [self formatWalletName:masterWalletID], @"with seed"];
            return [self errorProcess:command code:errCodeImportFromMnemonic msg:msg];
        }
        NSString *jsonString = [self getBasicInfo:masterWallet];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = "import wallet with seed ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = "create multi sign master wallet with mnemonic ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = "create multi sign master wallet ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = "create multi sign master wallet ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)getAddresses:(CDVInvokedUrlCommand *)command
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
        Json json = subWallet->GetAddresses(start, count, internal);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " getAddress ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)getPublicKeys:(CDVInvokedUrlCommand *)command
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
        Json json = subWallet->GetPublicKeys(start, count, internal);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " get public keys ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
    int version              = [args[idx++] intValue];
    Json inputs              = [self jsonWithString:args[idx++]];
    String sideChainID       = [self cstringWithString:args[idx++]];
    String amount            = [self cstringWithString:args[idx++]];
    String sideChainAddress  = [self cstringWithString:args[idx++]];
    String lockAddress       = [self cstringWithString:args[idx++]];
    String fee               = [self cstringWithString:args[idx++]];
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
        Json json = mainchainSubWallet->CreateDepositTransaction(version, inputs, sideChainID, amount, sideChainAddress, lockAddress, fee, memo);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create deposit transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
            String msg = masterWalletID + " destroy master wallet ";
            return [self exceptionProcess:command string:e.what() msg:msg];
        }
    });
}

- (void)createTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json outputs          = [self jsonWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IElastosBaseSubWallet *subWallet = [self getElastosBaseSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->CreateTransaction(inputs, outputs, fee, memo);
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" + chainID + " sign transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}


- (void)signDigest:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String address        = [self cstringWithString:args[idx++]];
    String digest         = [self cstringWithString:args[idx++]];
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
        String ret = subWallet->SignDigest(address, digest, payPassword);
        NSString *jsonString = [self stringWithJson:ret];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " sign digest ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)verifyDigest:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String publicKey      = [self cstringWithString:args[idx++]];
    String digest         = [self cstringWithString:args[idx++]];
    String signature      = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    ISubWallet *subWallet = [self getSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Boolean ret = subWallet->VerifyDigest(publicKey, digest, signature);
        CDVPluginResult*  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:ret];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " verify digest ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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

    IElastosBaseSubWallet *subWallet = [self getElastosBaseSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json resultJson = subWallet->GetTransactionSignedInfo(rawTxJson);
        NSString *jsonString = [self stringWithJson:resultJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " get transaction signed info ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)convertToRawTransaction:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json txJson           = [self jsonWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    IElastosBaseSubWallet *subWallet = [self getElastosBaseSubWallet:masterWalletID :chainID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        String rawTx = subWallet->ConvertToRawTransaction(txJson);
        NSString *jsonString = [self stringWithCString:rawTx];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " convert to raw transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createIdTransaction:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json payloadJson      = [self jsonWithDict:args[idx++]];
    String memo           = [self cstringWithString:args[idx++]];
    String fee            = args.count == idx ? "10000" : [self cstringWithString:args[idx]];

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
        Json json = idchainSubWallet->CreateIDTransaction(inputs, payloadJson, memo, fee);
        NSString *msg = [self stringWithJson:json];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create id transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createWithdrawTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String mainchainAddress  = [self cstringWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json json = sidechainSubWallet->CreateWithdrawTransaction(inputs, amount, mainchainAddress, fee, memo);
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create withdraw transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        masterWallet->DestroyWallet(chainID);

        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Destroy", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + " destroy " + chainID;
        return [self exceptionProcess:command string:e.what() msg:msg];
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

    s_logLevel = loglevel;
    if (nil != mMasterWalletManager) {
        mMasterWalletManager->SetLogLevel(loglevel);
    }
    return [self successAsString:command msg:@"SetLogLevel OK"];
}

- (void)setNetwork:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    s_netType           = args[idx++];
    s_netConfig         = args[idx++];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }

    return [self successAsString:command msg:@""];
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
        String msg = masterWalletID + ":" + chainID + " generate producer payload ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        Json payloadJson = mainchainSubWallet->GenerateCancelProducerPayload(publicKey, payPasswd);
        NSString *jsonString = [self stringWithJson:payloadJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " generate cancel producer payload ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createRegisterProducerTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json txJson = mainchainSubWallet->CreateRegisterProducerTransaction(inputs, payloadJson, amount, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create register producer transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createUpdateProducerTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json txJson = mainchainSubWallet->CreateUpdateProducerTransaction(inputs, payloadJson, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create update producer transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createCancelProducerTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json txJson =  mainchainSubWallet->CreateCancelProducerTransaction(inputs, payloadJson, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create cancel producer transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createRetrieveDepositTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json txJson =  mainchainSubWallet->CreateRetrieveDepositTransaction(inputs, amount, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create retrieve deposit transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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

- (void)getOwnerAddress:(CDVInvokedUrlCommand *)command
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

    String msg = mainchainSubWallet->GetOwnerAddress();
    NSString *jsonString = [self stringWithCString:msg];
    return [self successAsString:command msg:jsonString];
}

- (void)getOwnerDepositAddress:(CDVInvokedUrlCommand *)command
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

    String msg = mainchainSubWallet->GetOwnerDepositAddress();
    NSString *jsonString = [self stringWithCString:msg];
    return [self successAsString:command msg:jsonString];
}

// CR
- (void)getCRDepositAddress:(CDVInvokedUrlCommand *)command
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

    String msg = mainchainSubWallet->GetCRDepositAddress();
    NSString *jsonString = [self stringWithCString:msg];
    return [self successAsString:command msg:jsonString];
}

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
        String msg = masterWalletID + ":" + chainID + " generate CR info payload ";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" + chainID + " generate unregister CR payload ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createRegisterCRTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;
    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json txJson = mainchainSubWallet->CreateRegisterCRTransaction(inputs, payloadJson, amount, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " generate register CR transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createUpdateCRTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json txJson = mainchainSubWallet->CreateUpdateCRTransaction(inputs, payloadJson, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create update CR transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createUnregisterCRTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json payloadJson      = [self jsonWithString:args[idx++]];
    String fee           = [self cstringWithString:args[idx++]];
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
        Json txJson =  mainchainSubWallet->CreateUnregisterCRTransaction(inputs, payloadJson, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create unregister CR transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createRetrieveCRDepositTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json txJson =  mainchainSubWallet->CreateRetrieveCRDepositTransaction(inputs, amount, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID + " create retrieve CR deposit transaction ";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)CRCouncilMemberClaimNodeDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json payload          = [self jsonWithString:args[idx++]];

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
        String msg = masterWalletID + ":" + chainID +  " CR council member claim node digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createCRCouncilMemberClaimNodeTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json payload          = [self jsonWithString:args[idx++]];
    String fee            = [self cstringWithString:args[idx++]];
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
        Json txJson =  mainchainSubWallet->CreateCRCouncilMemberClaimNodeTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create CR council member claim node transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createVoteTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID  = [self cstringWithString:args[idx++]];
    String chainID         = [self cstringWithString:args[idx++]];
    Json inputs            = [self jsonWithString:args[idx++]];
    Json voteContents      = [self jsonWithString:args[idx++]];
    String fee             = [self cstringWithString:args[idx++]];
    String memo            = [self cstringWithString:args[idx++]];

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
        Json txJson = mainchainSubWallet->CreateVoteTransaction(inputs, voteContents, fee, memo);
        NSString *jsonString = [self stringWithJson:txJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create vote transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)proposalOwnerDigest:(CDVInvokedUrlCommand *)command
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
    if (mainchainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", [self formatWalletNameWithString:masterWalletID other:chainID], @" is not instance of IMainchainSubWallet"];
        return [self errorProcess:command code:errCodeSubWalletInstance msg:msg];
    }

    try {
        Json stringJson = mainchainSubWallet->ProposalOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " proposal owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)proposalCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID       = [self cstringWithString:args[idx++]];
    String chainID              = [self cstringWithString:args[idx++]];
    Json   payload              = [self jsonWithString:args[idx++]];

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
        String msg = masterWalletID + ":" + chainID +  " proposal CR council member digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)calculateProposalHash:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID       = [self cstringWithString:args[idx++]];
    String chainID              = [self cstringWithString:args[idx++]];
    Json   payload              = [self jsonWithString:args[idx++]];

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
        String msg = masterWalletID + ":" + chainID +  " calculate proposal hash";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createProposalTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID  = [self cstringWithString:args[idx++]];
    String chainID         = [self cstringWithString:args[idx++]];
    Json inputs            = [self jsonWithString:args[idx++]];
    Json payload           = [self jsonWithString:args[idx++]];
    String fee             = [self cstringWithString:args[idx++]];
    String memo            = [self cstringWithString:args[idx++]];

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
        Json stringJson = mainchainSubWallet->CreateProposalTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create proposal transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)proposalReviewDigest:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json   payload          = [self jsonWithString:args[idx++]];

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
        String msg = masterWalletID + ":" + chainID +  " proposal review digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createProposalReviewTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateProposalReviewTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create proposal review transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" + chainID +  " proposal tracking owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" + chainID +  " proposal tracking new owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" + chainID +  " proposal tracking secretary digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" + chainID +  " proposal withdraw digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createProposalWithdrawTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateProposalWithdrawTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create proposal withdraw transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createProposalTrackingTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateProposalTrackingTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create proposal tracking transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

// Proposal Secretary General Election
- (void)proposalSecretaryGeneralElectionDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ProposalSecretaryGeneralElectionDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " proposal secretary general election digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)proposalSecretaryGeneralElectionCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ProposalSecretaryGeneralElectionCRCouncilMemberDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " proposal secretary general election CRC member digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createSecretaryGeneralElectionTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateSecretaryGeneralElectionTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create secretary general election transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

// Proposal Change Owner
- (void)proposalChangeOwnerDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ProposalChangeOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " proposal change owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)proposalChangeOwnerCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ProposalChangeOwnerCRCouncilMemberDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " proposal change owner CRC member digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createProposalChangeOwnerTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateProposalChangeOwnerTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create proposal change owner transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

// Proposal Terminate Proposal
- (void)terminateProposalOwnerDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->TerminateProposalOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " terminate proposal owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)terminateProposalCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->TerminateProposalCRCouncilMemberDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " terminate proposal CRC member digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createTerminateProposalTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateTerminateProposalTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create terminate proposal transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

// Reserve Custom ID
- (void)reserveCustomIDOwnerDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ReserveCustomIDOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " reserve custom ID owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)reserveCustomIDCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ReserveCustomIDCRCouncilMemberDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " reserve custom ID CRC member digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createReserveCustomIDTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateReserveCustomIDTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create reserve custom ID transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

// Receive Custom ID
- (void)receiveCustomIDOwnerDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ReceiveCustomIDOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " receive custom ID owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)receiveCustomIDCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ReceiveCustomIDCRCouncilMemberDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " receive custom ID CRC member digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createReceiveCustomIDTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateReceiveCustomIDTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create receive custom ID transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

// Change Custom ID Fee
- (void)changeCustomIDFeeOwnerDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ChangeCustomIDFeeOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " change custom ID fee owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)changeCustomIDFeeCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->ChangeCustomIDFeeCRCouncilMemberDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " change custom ID fee CRC memeber digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createChangeCustomIDFeeTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateChangeCustomIDFeeTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create change custom ID fee transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

// Proposal Register side-chain
- (void)registerSidechainOwnerDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->RegisterSidechainOwnerDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " register sidechain owner digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)registerSidechainCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command
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
        Json stringJson = mainchainSubWallet->RegisterSidechainCRCouncilMemberDigest(payload);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " register sidechain CRC member digest";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createRegisterSidechainTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID   = [self cstringWithString:args[idx++]];
    String chainID          = [self cstringWithString:args[idx++]];
    Json inputs             = [self jsonWithString:args[idx++]];
    Json payload            = [self jsonWithString:args[idx++]];
    String fee              = [self cstringWithString:args[idx++]];
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
        Json stringJson = mainchainSubWallet->CreateRegisterSidechainTransaction(inputs, payload, fee, memo);
        NSString *jsonString = [self stringWithJson:stringJson];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" + chainID +  " create register sidechain transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

String const IDChain = "IDChain";

- (IIDChainSubWallet*) getIDChainSubWallet:(String)masterWalletID {
     ISubWallet* subWallet = [self getSubWallet:masterWalletID :IDChain];

    return dynamic_cast<IIDChainSubWallet *>(subWallet);
 }

- (void)getDID:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    int start           = [args[idx++] intValue];
    int count           = [args[idx++] intValue];
    Boolean internal    = [args[idx++] boolValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:masterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:IDChain]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = idChainSubWallet->GetDID(start, count, internal);
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" +  " get did";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}


- (void)getCID:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    int start           = [args[idx++] intValue];
    int count           = [args[idx++] intValue];
    Boolean internal    = [args[idx++] boolValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IIDChainSubWallet* idChainSubWallet = [self getIDChainSubWallet:masterWalletID];
    if (idChainSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:IDChain]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = idChainSubWallet->GetCID(start, count, internal);
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":" +  " get cid";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" +  " sign";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" +  " Verify Signature";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" +  " get public key DID";
        return [self exceptionProcess:command string:e.what() msg:msg];
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
        String msg = masterWalletID + ":" +  " get public key CID";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createTransfer:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String targetAddress  = [self cstringWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    int amountUnit        = [args[idx++] intValue];
    String gasPrice       = [self cstringWithString:args[idx++]];
    int gasPriceUnit      = [args[idx++] intValue];
    String gasLimit       = [self cstringWithString:args[idx++]];
    long   nonce          = [args[idx++] longValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IEthSidechainSubWallet* ethscSubWallet = [self getEthSidechainSubWallet:masterWalletID :chainID];
    if (ethscSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = ethscSubWallet->CreateTransfer(targetAddress, amount, amountUnit, gasPrice, gasPriceUnit, gasLimit, nonce);
        NSString *msg = [self stringWithJson:json];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":ETHSC" +  " create transfer";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createTransferGeneric:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String targetAddress  = [self cstringWithString:args[idx++]];
    String amount         = [self cstringWithString:args[idx++]];
    int amountUnit        = [args[idx++] intValue];
    String gasPrice       = [self cstringWithString:args[idx++]];
    int gasPriceUnit      = [args[idx++] intValue];
    String gasLimit       = [self cstringWithString:args[idx++]];
    String data           = [self cstringWithString:args[idx++]];
    long   nonce          = [args[idx++] longValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IEthSidechainSubWallet* ethscSubWallet = [self getEthSidechainSubWallet:masterWalletID :chainID];
    if (ethscSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = ethscSubWallet->CreateTransferGeneric(targetAddress, amount, amountUnit, gasPrice, gasPriceUnit, gasLimit, data, nonce);
        NSString *msg = [self stringWithJson:json];
        return [self successAsString:command msg:msg];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":ETHSC" +  " create transfer generic";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)exportETHSCPrivateKey:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    String chainID        = [self cstringWithString:args[idx++]];
    String password       = [self cstringWithString:args[idx++]];


    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IEthSidechainSubWallet* ethscSubWallet = [self getEthSidechainSubWallet:masterWalletID :chainID];
    if (ethscSubWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:chainID]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        String ret = ethscSubWallet->ExportPrivateKey(password);
        NSString *jsonString = [self stringWithJson:ret];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":ETHSC" +  " export private key";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

// BTCSubwallet

- (void)getLegacyAddresses:(CDVInvokedUrlCommand *)command
{
    NSArray *args = command.arguments;
    int idx = 0;

    String masterWalletID = [self cstringWithString:args[idx++]];
    int start             = [args[idx++] intValue];
    int count             = [args[idx++] intValue];
    Boolean internal      = [args[idx++] boolValue];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IBTCSubWallet *subWallet = [self getBTCSubWallet:masterWalletID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:"BTC"]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->GetLegacyAddresses(start, count, internal);
        NSString *jsonString = [self stringWithCString:json.dump()];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":BTC" +  " get legacy addresses";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}

- (void)createBTCTransaction:(CDVInvokedUrlCommand *)command
{
    int idx = 0;
    NSArray *args = command.arguments;

    String masterWalletID = [self cstringWithString:args[idx++]];
    Json inputs           = [self jsonWithString:args[idx++]];
    Json outputs          = [self jsonWithString:args[idx++]];
    String changeAddress  = [self cstringWithString:args[idx++]];
    String feePerKB        = [self cstringWithString:args[idx++]];

    if (args.count != idx) {
        return [self errCodeInvalidArg:command code:errCodeInvalidArg idx:idx];
    }
    IBTCSubWallet *subWallet = [self getBTCSubWallet:masterWalletID];
    if (subWallet == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@ %@", @"Get", [self formatWalletNameWithString:masterWalletID other:"BTC"]];
        return [self errorProcess:command code:errCodeInvalidSubWallet msg:msg];
    }

    try {
        Json json = subWallet->CreateTransaction(inputs, outputs, changeAddress, feePerKB);
        NSString *jsonString = [self stringWithJson:json];
        return [self successAsString:command msg:jsonString];
    } catch (const std:: exception &e) {
        String msg = masterWalletID + ":BTC" +  " create transaction";
        return [self exceptionProcess:command string:e.what() msg:msg];
    }
}


@end
