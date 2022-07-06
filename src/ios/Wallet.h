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
#import <Cordova/CDVPlugin.h>
#import "IMasterWallet.h"
#import "MasterWalletManager.h"
#import "IBTCSubWallet.h"
#import "IElastosBaseSubWallet.h"
#import "ISidechainSubWallet.h"
#import "IMainchainSubWallet.h"
#import "IIDChainSubWallet.h"
#import "IEthSidechainSubWallet.h"
#import <string.h>
#import <map>

typedef Elastos::ElaWallet::IMasterWallet IMasterWallet;
typedef Elastos::ElaWallet::MasterWalletManager MasterWalletManager;
typedef Elastos::ElaWallet::ISubWallet ISubWallet;
typedef std::string String;
typedef nlohmann::json Json;
typedef std::vector<IMasterWallet *> IMasterWalletVector;
typedef std::vector<ISubWallet *> ISubWalletVector;
typedef std::vector<String> StringVector;

typedef Elastos::ElaWallet::ISidechainSubWallet ISidechainSubWallet;
typedef Elastos::ElaWallet::IMainchainSubWallet IMainchainSubWallet;
typedef Elastos::ElaWallet::IIDChainSubWallet IIDChainSubWallet;

static int walletRefCount = 0;
static MasterWalletManager *mMasterWalletManager = nil;
static dispatch_semaphore_t walletSemaphore;

NSString* s_dataRootPath = @"";
NSString* s_netType = @"MainNet";
NSString* s_netConfig = @"";
String s_logLevel = "warning";

@interface Wallet : CDVPlugin {
    NSString *TAG; //= @"Wallet";

    NSString *keySuccess;//   = "success";
    NSString *keyError;//     = "error";
    NSString *keyCode;//      = "code";
    NSString *keyMessage;//   = "message";
    NSString *keyException;// = "exception";
    NSString *listenerCallbackId;

    int errCodeParseJsonInAction;//          = 10000;
    int errCodeInvalidArg      ;//           = 10001;
    int errCodeInvalidMasterWallet ;//       = 10002;
    int errCodeInvalidSubWallet    ;//       = 10003;
    int errCodeCreateMasterWallet  ;//       = 10004;
    int errCodeCreateSubWallet     ;//       = 10005;
    int errCodeRecoverSubWallet    ;//       = 10006;
    int errCodeInvalidMasterWalletManager;// = 10007;
    int errCodeImportFromKeyStore     ;//    = 10008;
    int errCodeImportFromMnemonic      ;//   = 10009;
    int errCodeSubWalletInstance      ;//    = 10010;
    int errCodeInvalidDIDManager      ;//    = 10011;
    int errCodeInvalidDID               ;//  = 10012;
    int errCodeActionNotFound           ;//  = 10013;
    int errCodeGetAllMasterWallets      ;//  = 10014;

    int errCodeWalletException         ;//   = 20000;
}

- (void)pluginInitialize;
- (void)init:(CDVInvokedUrlCommand *)command;
- (void)destroy:(CDVInvokedUrlCommand *)command;
- (void)getAllMasterWallets:(CDVInvokedUrlCommand *)command;
- (void)createMasterWallet:(CDVInvokedUrlCommand *)command;
- (void)createMasterWalletWithPrivKey:(CDVInvokedUrlCommand *)command;
- (void)generateMnemonic:(CDVInvokedUrlCommand *)command;
- (void)createSubWallet:(CDVInvokedUrlCommand *)command;
- (void)getAllSubWallets:(CDVInvokedUrlCommand *)command;
- (void)getSupportedChains:(CDVInvokedUrlCommand *)command;
- (void)getMasterWalletBasicInfo:(CDVInvokedUrlCommand *)command;
- (void)exportWalletWithKeystore:(CDVInvokedUrlCommand *)command;
- (void)exportWalletWithMnemonic:(CDVInvokedUrlCommand *)command;
- (void)exportWalletWithSeed:(CDVInvokedUrlCommand *)command;
- (void)exportWalletWithPrivateKey:(CDVInvokedUrlCommand *)command;
- (void)verifyPassPhrase:(CDVInvokedUrlCommand *)command;
- (void)verifyPayPassword:(CDVInvokedUrlCommand *)command;
- (void)changePassword:(CDVInvokedUrlCommand *)command;
- (void)getPubKeyInfo:(CDVInvokedUrlCommand *)command;
- (void)importWalletWithKeystore:(CDVInvokedUrlCommand *)command;
- (void)importWalletWithMnemonic:(CDVInvokedUrlCommand *)command;
- (void)importWalletWithSeed:(CDVInvokedUrlCommand *)command;
- (void)createMultiSignMasterWalletWithMnemonic:(CDVInvokedUrlCommand *)command;
- (void)createMultiSignMasterWallet:(CDVInvokedUrlCommand *)command;
- (void)createMultiSignMasterWalletWithPrivKey:(CDVInvokedUrlCommand *)command;
- (void)getAddresses:(CDVInvokedUrlCommand *)command;
- (void)getPublicKeys:(CDVInvokedUrlCommand *)command;
- (void)isAddressValid:(CDVInvokedUrlCommand *)command;
- (void)isSubWalletAddressValid:(CDVInvokedUrlCommand *)command;
- (void)destroyWallet:(CDVInvokedUrlCommand *)command;
- (void)createTransaction:(CDVInvokedUrlCommand *)command;
- (void)signTransaction:(CDVInvokedUrlCommand *)command;
- (void)signDigest:(CDVInvokedUrlCommand *)command;
- (void)verifyDigest:(CDVInvokedUrlCommand *)command;
- (void)getTransactionSignedInfo:(CDVInvokedUrlCommand *)command;
- (void)convertToRawTransaction:(CDVInvokedUrlCommand *)command;
- (void)createIdTransaction:(CDVInvokedUrlCommand *)command;
- (void)createWithdrawTransaction:(CDVInvokedUrlCommand *)command;
- (void)getMasterWallet:(CDVInvokedUrlCommand *)command;
- (void)destroySubWallet:(CDVInvokedUrlCommand *)command;
- (void)getVersion:(CDVInvokedUrlCommand *)command;
- (void)setLogLevel:(CDVInvokedUrlCommand *)command;
- (void)setNetwork:(CDVInvokedUrlCommand *)command;

// MainchainSubwallet
- (void)createDepositTransaction:(CDVInvokedUrlCommand *)command;
// Vote
- (void)createVoteTransaction:(CDVInvokedUrlCommand *)command;

// Producer
- (void)generateProducerPayload:(CDVInvokedUrlCommand *)command;
- (void)generateCancelProducerPayload:(CDVInvokedUrlCommand *)command;
- (void)createRegisterProducerTransaction:(CDVInvokedUrlCommand *)command;
- (void)createUpdateProducerTransaction:(CDVInvokedUrlCommand *)command;
- (void)createCancelProducerTransaction:(CDVInvokedUrlCommand *)command;
- (void)createRetrieveDepositTransaction:(CDVInvokedUrlCommand *)command;
- (void)getOwnerPublicKey:(CDVInvokedUrlCommand *)command;
- (void)getOwnerAddress:(CDVInvokedUrlCommand *)command;
- (void)getOwnerDepositAddress:(CDVInvokedUrlCommand *)command;

// CRC
- (void)getCRDepositAddress:(CDVInvokedUrlCommand *)command;
- (void)generateCRInfoPayload:(CDVInvokedUrlCommand *)command;
- (void)generateUnregisterCRPayload:(CDVInvokedUrlCommand *)command;
- (void)createRegisterCRTransaction:(CDVInvokedUrlCommand *)command;
- (void)createUpdateCRTransaction:(CDVInvokedUrlCommand *)command;
- (void)createUnregisterCRTransaction:(CDVInvokedUrlCommand *)command;
- (void)createRetrieveCRDepositTransaction:(CDVInvokedUrlCommand *)command;
- (void)CRCouncilMemberClaimNodeDigest:(CDVInvokedUrlCommand *)command;
- (void)createCRCouncilMemberClaimNodeTransaction:(CDVInvokedUrlCommand *)command;

// Proposal
- (void)proposalOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)proposalCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command;
- (void)calculateProposalHash:(CDVInvokedUrlCommand *)command;
- (void)createProposalTransaction:(CDVInvokedUrlCommand *)command;
- (void)proposalReviewDigest:(CDVInvokedUrlCommand *)command;
- (void)createProposalReviewTransaction:(CDVInvokedUrlCommand *)command;

// Proposal Tracking
- (void)proposalTrackingOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)proposalTrackingNewOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)proposalTrackingSecretaryDigest:(CDVInvokedUrlCommand *)command;
- (void)createProposalTrackingTransaction:(CDVInvokedUrlCommand *)command;

// TODO
// Proposal Secretary General Election
- (void)proposalSecretaryGeneralElectionDigest:(CDVInvokedUrlCommand *)command;
- (void)proposalSecretaryGeneralElectionCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command;
- (void)createSecretaryGeneralElectionTransaction:(CDVInvokedUrlCommand *)command;
// Proposal Change Owner
- (void)proposalChangeOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)proposalChangeOwnerCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command;
- (void)createProposalChangeOwnerTransaction:(CDVInvokedUrlCommand *)command;
// Proposal Terminate Proposal
- (void)terminateProposalOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)terminateProposalCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command;
- (void)createTerminateProposalTransaction:(CDVInvokedUrlCommand *)command;

// Reserve Custom ID
- (void)reserveCustomIDOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)reserveCustomIDCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command;
- (void)createReserveCustomIDTransaction:(CDVInvokedUrlCommand *)command;

// Receive Custom ID
- (void)receiveCustomIDOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)receiveCustomIDCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command;
- (void)createReceiveCustomIDTransaction:(CDVInvokedUrlCommand *)command;

// Change Custom ID Fee
- (void)changeCustomIDFeeOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)changeCustomIDFeeCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command;
- (void)createChangeCustomIDFeeTransaction:(CDVInvokedUrlCommand *)command;

// Proposal Withdraw
- (void)proposalWithdrawDigest:(CDVInvokedUrlCommand *)command;
- (void)createProposalWithdrawTransaction:(CDVInvokedUrlCommand *)command;

// Proposal Register side-chain
- (void)registerSidechainOwnerDigest:(CDVInvokedUrlCommand *)command;
- (void)registerSidechainCRCouncilMemberDigest:(CDVInvokedUrlCommand *)command;
- (void)createRegisterSidechainTransaction:(CDVInvokedUrlCommand *)command;

- (void)getDID:(CDVInvokedUrlCommand *)command;
- (void)getCID:(CDVInvokedUrlCommand *)command;
- (void)didSign:(CDVInvokedUrlCommand *)command;
- (void)verifySignature:(CDVInvokedUrlCommand *)command;
- (void)getPublicKeyDID:(CDVInvokedUrlCommand *)command;
- (void)getPublicKeyCID:(CDVInvokedUrlCommand *)command;

//ETHSidechain
- (void)createTransfer:(CDVInvokedUrlCommand *)command;
- (void)createTransferGeneric:(CDVInvokedUrlCommand *)command;
- (void)exportETHSCPrivateKey:(CDVInvokedUrlCommand *)command;

//BTCSidechain
- (void)getLegacyAddresses:(CDVInvokedUrlCommand *)command;
- (void)createBTCTransaction:(CDVInvokedUrlCommand *)command;

@end
