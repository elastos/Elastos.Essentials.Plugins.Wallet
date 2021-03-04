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
#import "TrinityPlugin.h"

@protocol ElISubWalletDelegate
- (void)onTransactionStatusChangedTxId:(NSString *)txIdStr
                                status:(NSString *)statusStr
                                  desc:(NSString *)descStr
                               confirm:(NSNumber *)confirmNum;

- (void)onBlockSyncProgressWithProgressInfo:(NSDictionary *)info;

- (void)onBalanceChangedAsset:(NSString *)assetString
                      balance:(NSString *)balanceString;

- (void)onTxPublishedHash:(NSString *)hashString
                   result:(NSDictionary *)resultString;

- (void)onAssetRegisteredAsset:(NSString *)assetString
                          info:(NSString *)infoString;

- (void)onConnectStatusChangedStatus:(NSString *)statusString;

@end

@interface SPVWallet : TrinityPlugin

+(instancetype)sharedWallet;

- (NSDictionary *)getMasterWalletBasicInfo:(NSString *)masterWalletID
                                     error:(NSError **)error;

- (void)registerWalletListener:(NSString *)masterWalletID
                       chainID:(NSString *)chainID
                      delegate:(id<ElISubWalletDelegate>)delegate;

- (NSArray<NSString *> *)getAllMasterWallets;

- (NSArray<NSString *> *)getAllSubWalletsWithMasterWalletID:(NSString *)masterWalletID
                                                      error:(NSError **)error;

- (NSString *)syncStartMasterWalletID:(NSString *)masterWalletID
                              chainID:(NSString *)chainID
                                error:(NSError **)error;

- (NSString *)generateMnemonicWithLanguage:(NSString *)language
                                     error:(NSError **)error;

- (NSDictionary *)createMasterWalletWithMasterWalletID:(NSString *)masterWalletID
                                              mnemonic:(NSString *)mnemonic
                                        phrasePassword:(NSString *)phrasePassword
                                           payPassword:(NSString *)payPassword
                                         singleAddress:(NSNumber *)singleAddress
                                                 error:(NSError **)error;

- (NSString *)getBalance:(NSString *)masterWalletID
                 chainID:(NSString *)chainID
                   error:(NSError **)error;

- (NSDictionary *)createSubWallet:(NSString *)masterWalletID
                          chainID:(NSString *)chainID
                            error:(NSError **)error;

- (NSDictionary *)getAllTransaction:(NSString *)masterWalletID
                            chainID:(NSString *)chainID
                              start:(NSString *)start
                              count:(NSString *)count
                      addressOrTxId:(NSString *)addressOrTxId
                              error:(NSError **)error;

- (NSString *)createAddress:(NSString *)masterWalletID
                    chainID:(NSString *)chainID
                      error:(NSError **)error;

- (BOOL)isAddressValid:(NSString *)masterWalletID
                  addr:(NSString *)addr
                 error:(NSError **)error;

- (NSString *)createTransaction:(NSString *)masterWalletID
                        chainID:(NSString *)chainID
                    fromAddress:(NSString *)fromAddress
                      toAddress:(NSString *)toAddress
                         amount:(NSString *)amount
                           memo:(NSString *)memo
                          error:(NSError **)error;

- (NSString *)signTransaction:(NSString *)masterWalletID
                      chainID:(NSString *)chainID
               rawTransaction:(NSString *)rawTransaction
                  payPassword:(NSString *)payPassword
                        error:(NSError **)error;

- (NSString *)publishTransaction:(NSString *)masterWalletID
                         chainID:(NSString *)chainID
                       rawTxJson:(NSString *)rawTxJson
                           error:(NSError **)error;

- (NSString *)exportMnemonicWithmasterWalletID:(NSString *)masterWalletID
                                backupPassword:(NSString *)backupPassword
                                         error:(NSError **)error;

- (NSString *)destroyWallet:(NSString *)masterWalletID
                      error:(NSError **)error;

- (NSArray *)getBalanceInfo:(NSString *)masterWalletID
                     chainID:(NSString *)chainID
                       error:(NSError **)error;

#pragma mark -  没有使用的api

- (NSArray *)getSupportedChains:(NSString *)masterWalletID
                          error:(NSError **)error;

- (NSString *)getGenesisAddress:(NSString *)masterWalletID
                        chainID:(NSString *)chainID
                          error:(NSError **)error;

- (NSString *)exportWalletWithKeystore:(NSString *)masterWalletID
                        backupPassword:(NSString *)backupPassword
                           payPassword:(NSString *)payPassword
                                 error:(NSError **)error;

- (void)changePassword:(NSString *)masterWalletID
           oldPassword:(NSString *)oldPassword
           newPassword:(NSString *)newPassword
                 error:(NSError **)error;

- (NSDictionary *)importWalletWithKeystore:(NSString *)masterWalletID
                           keystoreContent:(NSString *)keystoreContent
                            backupPassword:(NSString *)backupPassword
                               payPassword:(NSString *)payPassword
                                     error:(NSError **)error;

- (NSDictionary *)importWalletWithMnemonic:(NSString *)masterWalletID
                                  mnemonic:(NSString *)mnemonic
                            phrasePassword:(NSString *)phrasePassword
                               payPassword:(NSString *)payPassword
                             singleAddress:(NSString *)singleAddress
                                     error:(NSError **)error;

- (NSDictionary *)createMultiSignMasterWalletWithMnemonic:(NSString *)masterWalletID
                                                 mnemonic:(NSString *)mnemonic
                                           phrasePassword:(NSString *)phrasePassword
                                              payPassword:(NSString *)payPassword
                                               publicKeys:(NSString *)publicKeys
                                                        m:(NSString *)m
                                                timestamp:(NSString *)timestamp
                                                    error:(NSError **)error;

- (NSDictionary *)createMultiSignMasterWallet:(NSString *)masterWalletID
                                   publicKeys:(NSString *)publicKeys
                                            m:(NSString *)m
                                    timestamp:(NSString *)timestamp
                                        error:(NSError **)error;

- (NSDictionary *)createMultiSignMasterWalletWithPrivKey:(NSString *)masterWalletID
                                                 privKey:(NSString *)privKey
                                             payPassword:(NSString *)payPassword
                                              publicKeys:(NSString *)publicKeys
                                                       m:(NSString *)m
                                               timestamp:(NSString *)timestamp
                                                   error:(NSError **)error;

- (NSString *)getAllAddress:(NSString *)masterWalletID
                    chainID:(NSString *)chainID
                      start:(NSString *)start
                      count:(NSString *)count
                      error:(NSError **)error;

- (NSString *)getAllPublicKeys:(NSString *)masterWalletID
                       chainID:(NSString *)chainID
                         start:(NSString *)start
                         count:(NSString *)count
                         error:(NSError **)error;

- (NSString *)createDepositTransaction:(NSString *)masterWalletID
                               chainID:(NSString *)chainID
                           fromAddress:(NSString *)fromAddress
                         lockedAddress:(NSString *)lockedAddress
                                amount:(NSString *)amount
                      sideChainAddress:(NSString *)sideChainAddress
                                  memo:(NSString *)memo
                                 error:(NSError **)error;

- (NSString *)getAllUTXOs:(NSString *)masterWalletID
                  chainID:(NSString *)chainID
                    start:(NSString *)start
                    count:(NSString *)count
                  address:(NSString *)address
                    error:(NSError **)error;

- (NSString *)createConsolidateTransaction:(NSString *)masterWalletID
                                   chainID:(NSString *)chainID
                                      memo:(NSString *)memo
                                     error:(NSError **)error;

- (NSDictionary *)importWalletWithOldKeystore:(NSString *)masterWalletID
                              keystoreContent:(NSString *)keystoreContent
                               backupPassword:(NSString *)backupPassword
                                  payPassword:(NSString *)payPassword
                               phrasePassword:(NSString *)phrasePassword
                                        error:(NSError **)error;

- (NSString *)getTransactionSignedSigners:(NSString *)masterWalletID
                                  chainID:(NSString *)chainID
                                rawTxJson:(NSString *)rawTxJson
                                    error:(NSError **)error;

- (void)removeWalletListener:(NSString *)masterWalletID
                     chainID:(NSString *)chainID
                       error:(NSError **)error;

- (NSString *)createIdTransaction:(NSString *)masterWalletID
                          chainID:(NSString *)chainID
                      payloadJson:(NSDictionary *)payloadJson
                             memo:(NSString *)memo
                            error:(NSError **)error;

- (NSString *)createWithdrawTransaction:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                            fromAddress:(NSString *)fromAddress
                                 amount:(NSString *)amount
                       mainchainAddress:(NSString *)mainchainAddress
                                   memo:(NSString *)memo
                                  error:(NSError **)error;

- (NSDictionary *)getMasterWallet:(NSString *)masterWalletID
                            error:(NSError **)error;

- (void)destroySubWallet:(NSString *)masterWalletID
                 chainID:(NSString *)chainID
                   error:(NSError **)error;

- (NSString *)getVersionWithError:(NSError **)error;

- (NSString *)generateProducerPayload:(NSString *)masterWalletID
                              chainID:(NSString *)chainID
                            publicKey:(NSString *)publicKey
                        nodePublicKey:(NSString *)nodePublicKey
                             nickName:(NSString *)nickName
                                  url:(NSString *)url
                            IPAddress:(NSString *)IPAddress
                             location:(NSString *)location
                            payPasswd:(NSString *)payPasswd
                                error:(NSError **)error;

- (NSString *)generateCancelProducerPayload:(NSString *)masterWalletID
                                    chainID:(NSString *)chainID
                                  publicKey:(NSString *)publicKey
                                  payPasswd:(NSString *)payPasswd
                                      error:(NSError **)error;

- (NSString *)createRegisterProducerTransaction:(NSString *)masterWalletID
                                        chainID:(NSString *)chainID
                                    fromAddress:(NSString *)fromAddress
                                    payloadJson:(NSString *)payloadJson
                                         amount:(NSString *)amount
                                           memo:(NSString *)memo
                                          error:(NSError **)error;

- (NSString *)createUpdateProducerTransaction:(NSString *)masterWalletID
                                      chainID:(NSString *)chainID
                                  fromAddress:(NSString *)fromAddress
                                  payloadJson:(NSString *)payloadJson
                                         memo:(NSString *)memo
                                        error:(NSError **)error;

- (NSString *)createRetrieveDepositTransaction:(NSString *)masterWalletID
                                       chainID:(NSString *)chainID
                                        amount:(NSString *)amount
                                          memo:(NSString *)memo
                                         error:(NSError **)error;

- (NSString *)getOwnerPublicKey:(NSString *)masterWalletID
                        chainID:(NSString *)chainID
                          error:(NSError **)error;

- (NSString *)createVoteProducerTransaction:(NSString *)masterWalletID
                                    chainID:(NSString *)chainID
                                fromAddress:(NSString *)fromAddress
                                      stake:(NSString *)stake
                                 publicKeys:(NSString *)publicKeys
                                       memo:(NSString *)memo
                                      error:(NSError **)error;

- (NSString *)getVotedProducerList:(NSString *)masterWalletID
                           chainID:(NSString *)chainID
                             error:(NSError **)error;

- (NSString *)getRegisteredProducerInfo:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                                  error:(NSError **)error;

- (NSString *)generateCRInfoPayload:(NSString *)masterWalletID
                            chainID:(NSString *)chainID
                        crPublicKey:(NSString *)crPublicKey
                                did:(NSString *)did
                           nickName:(NSString *)nickName
                                url:(NSString *)url
                           location:(NSString *)location
                              error:(NSError **)error;

- (NSString *)generateUnregisterCRPayload:(NSString *)masterWalletID
                                  chainID:(NSString *)chainID
                                      did:(NSString *)did
                                    error:(NSError **)error;

- (NSString *)createRegisterCRTransaction:(NSString *)masterWalletID
                                  chainID:(NSString *)chainID
                              fromAddress:(NSString *)fromAddress
                              payloadJson:(NSString *)payloadJson
                                   amount:(NSString *)amount
                                     memo:(NSString *)memo
                                    error:(NSError **)error;

- (NSString *)createUpdateCRTransaction:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                            fromAddress:(NSString *)fromAddress
                            payloadJson:(NSString *)payloadJson
                                   memo:(NSString *)memo
                                  error:(NSError **)error;

- (NSString *)createUnregisterCRTransaction:(NSString *)masterWalletID
                                    chainID:(NSString *)chainID
                                fromAddress:(NSString *)fromAddress
                                payloadJson:(NSString *)payloadJson
                                       memo:(NSString *)memo
                                      error:(NSError **)error;

- (NSString *)createRetrieveCRDepositTransaction:(NSString *)masterWalletID
                                         chainID:(NSString *)chainID
                                     crPublicKey:(NSString *)crPublicKey
                                          amount:(NSString *)amount
                                            memo:(NSString *)memo
                                           error:(NSError **)error;

- (NSString *)createVoteCRTransaction:(NSString *)masterWalletID
                              chainID:(NSString *)chainID
                          fromAddress:(NSString *)fromAddress
                           publicKeys:(NSDictionary *)publicKeys
                                 memo:(NSString *)memo
                    invalidCandidates:(NSString *)invalidCandidates
                                error:(NSError **)error;

- (NSString *)getVotedCRList:(NSString *)masterWalletID
                     chainID:(NSString *)chainID
                       error:(NSError **)error;

- (NSString *)getRegisteredCRInfo:(NSString *)masterWalletID
                          chainID:(NSString *)chainID
                            error:(NSError **)error;

- (NSString *)getVoteInfo:(NSString *)masterWalletID
                  chainID:(NSString *)chainID
                     type:(NSString *)type
                    error:(NSError **)error;

- (NSString *)sponsorProposalDigest:(NSString *)masterWalletID
                            chainID:(NSString *)chainID
                               type:(NSString *)type
                       categoryData:(NSString *)categoryData
                   sponsorPublicKey:(NSString *)sponsorPublicKey
                          draftHash:(NSString *)draftHash
                            budgets:(NSString *)budgets
                          recipient:(NSString *)recipient
                              error:(NSError **)error;

- (NSString *)CRSponsorProposalDigest:(NSString *)masterWalletID
                              chainID:(NSString *)chainID
                sponsorSignedProposal:(NSString *)sponsorSignedProposal
                         crSponsorDID:(NSString *)crSponsorDID
                        crOpinionHash:(NSString *)crOpinionHash
                                error:(NSError **)error;

- (NSString *)createCRCProposalTransaction:(NSString *)masterWalletID
                                   chainID:(NSString *)chainID
                          crSignedProposal:(NSString *)crSignedProposal
                                      memo:(NSString *)memo
                                     error:(NSError **)error;

- (NSString *)generateCRCProposalReview:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                           proposalHash:(NSString *)proposalHash
                             voteResult:(NSString *)voteResult
                                    did:(NSString *)did
                                  error:(NSError **)error;

- (NSString *)createCRCProposalReviewTransaction:(NSString *)masterWalletID
                                         chainID:(NSString *)chainID
                                  proposalReview:(NSString *)proposalReview
                                            memo:(NSString *)memo
                                           error:(NSError **)error;

- (NSString *)createVoteCRCProposalTransaction:(NSString *)masterWalletID
                                       chainID:(NSString *)chainID
                                   fromAddress:(NSString *)fromAddress
                                         votes:(NSString *)votes
                                          memo:(NSString *)memo
                             invalidCandidates:(NSString *)invalidCandidates
                                         error:(NSError **)error;

- (NSString *)createImpeachmentCRCTransaction:(NSString *)masterWalletID
                                      chainID:(NSString *)chainID
                                  fromAddress:(NSString *)fromAddress
                                        votes:(NSString *)votes
                                         memo:(NSString *)memo
                            invalidCandidates:(NSString *)invalidCandidates
                                        error:(NSError **)error;

- (NSString *)leaderProposalTrackDigest:(NSString *)masterWalletID
                                chainID:(NSString *)chainID
                                   type:(NSString *)type
                           proposalHash:(NSString *)proposalHash
                           documentHash:(NSString *)documentHash
                                  stage:(NSString *)stage
                          appropriation:(NSString *)appropriation
                           leaderPubKey:(NSString *)leaderPubKey
                        newLeaderPubKey:(NSString *)newLeaderPubKey
                                  error:(NSError **)error;

- (NSString *)newLeaderProposalTrackDigest:(NSString *)masterWalletID
                                   chainID:(NSString *)chainID
              leaderSignedProposalTracking:(NSString *)leaderSignedProposalTracking
                                     error:(NSError **)error;

- (NSString *)secretaryGeneralProposalTrackDigest:(NSString *)masterWalletID
                                          chainID:(NSString *)chainID
                     leaderSignedProposalTracking:(NSString *)leaderSignedProposalTracking
                                            error:(NSError **)error;

- (NSString *)createProposalTrackingTransaction:(NSString *)masterWalletID
                                        chainID:(NSString *)chainID
                  SecretaryGeneralSignedPayload:(NSString *)SecretaryGeneralSignedPayload
                                           memo:(NSString *)memo
                                          error:(NSError **)error;

- (void)syncStop:(NSString *)masterWalletID
         chainID:(NSString *)chainID
           error:(NSError **)error;

- (NSString *)getResolveDIDInfo:(NSString *)masterWalletID
                          start:(NSString *)start
                          count:(NSString *)count
                            did:(NSString *)did
                          error:(NSError **)error;

- (NSString *)getAllDID:(NSString *)masterWalletID
                  start:(NSString *)start
                  count:(NSString *)count
                  error:(NSError **)error;

- (NSString *)didSign:(NSString *)masterWalletID
                  did:(NSString *)did
              message:(NSString *)message
          payPassword:(NSString *)payPassword
                error:(NSError **)error;

- (NSString *)didSignDigest:(NSString *)masterWalletID
                        did:(NSString *)did
                     digest:(NSString *)digest
                payPassword:(NSString *)payPassword
                      error:(NSError **)error;

- (BOOL)verifySignature:(NSString *)masterWalletID
              publicKey:(NSString *)publicKey
                message:(NSString *)message
              signature:(NSString *)signature
                  error:(NSError **)error;

- (NSString *)getPublicKeyDID:(NSString *)masterWalletID
                    publicKey:(NSString *)publicKey
                        error:(NSError **)error;

- (NSString *)generateDIDInfoPayload:(NSString *)masterWalletID
                             didInfo:(NSString *)didInfo
                           paypasswd:(NSString *)paypasswd
                               error:(NSError **)error;
@end
