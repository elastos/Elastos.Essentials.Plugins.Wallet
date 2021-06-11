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

let exec = cordova.exec;

function _exec(success, error, obj, fun, args) {
    function _onSuccess(ret) {
        if (success) {
            if (typeof(ret) == "string") {
                ret = JSON.parse(ret);
            }
            success(ret);
        }
    };
    exec(_onSuccess, error, obj, fun, args)
}

function execAsPromise<T>(method: string, params: any[] = []): Promise<T> {
    return new Promise((resolve, reject)=>{
        exec((result: any)=>{
            resolve(result);
        }, (err: any)=>{
            reject(err);
        }, 'Wallet', method, params);
    });
}

class WalletManagerImpl implements WalletPlugin.WalletManager {
    //MasterWalletManager

    init(args, success, error) {
        exec(success, error, "Wallet", "init", args);
    };

    destroy(args, success, error) {
       exec(success, error, "Wallet", "destroy", args);
    };

    generateMnemonic(args, success, error) {
        exec(success, error, "Wallet", "generateMnemonic", args);
    };

    createMasterWallet(args, success, error) {
        exec(success, error, "Wallet", "createMasterWallet", args);
    };

    createMultiSignMasterWallet(args, success, error) {
        exec(success, error, "Wallet", "createMultiSignMasterWallet", args);
    };

    createMultiSignMasterWalletWithPrivKey(args, success, error) {
        exec(success, error, "Wallet", "createMultiSignMasterWalletWithPrivKey", args);
    };

    createMultiSignMasterWalletWithMnemonic(args, success, error) {
        exec(success, error, "Wallet", "createMultiSignMasterWalletWithMnemonic", args);
    };

    importWalletWithKeystore(args, success, error) {
        exec(success, error, "Wallet", "importWalletWithKeystore", args);
    };

    importWalletWithMnemonic(args, success, error) {
        exec(success, error, "Wallet", "importWalletWithMnemonic", args);
    };

    getAllMasterWallets(args, success, error) {
        _exec(success, error, "Wallet", "getAllMasterWallets", args);
    };

    destroyWallet(args, success, error) {
        exec(success, error, "Wallet", "destroyWallet", args);
    };

    getVersion(args, success, error) {
        exec(success, error, "Wallet", "getVersion", args);
    };

    setLogLevel(args, success, error) {
        exec(success, error, "Wallet", "setLogLevel", args);
    };

    setNetwork(args, success, error) {
        exec(success, error, "Wallet", "setNetwork", args);
    };

    //MasterWallet

    getMasterWalletBasicInfo(args, success, error) {
        _exec(success, error, "Wallet", "getMasterWalletBasicInfo", args);
    };

    getAllSubWallets(args, success, error) {
        _exec(success, error, "Wallet", "getAllSubWallets", args);
    };

    createSubWallet(args, success, error) {
        exec(success, error, "Wallet", "createSubWallet", args);
    };

    exportWalletWithKeystore(args, success, error) {
        exec(success, error, "Wallet", "exportWalletWithKeystore", args);
    };

    exportWalletWithMnemonic(args, success, error) {
        exec(success, error, "Wallet", "exportWalletWithMnemonic", args);
    };

    verifyPassPhrase(args, success, error) {
        exec(success, error, "Wallet", "verifyPassPhrase", args);
    };

    verifyPayPassword(args, success, error) {
        exec(success, error, "Wallet", "verifyPayPassword", args);
    };

    destroySubWallet(args, success, error) {
        exec(success, error, "Wallet", "destroySubWallet", args);
    };

    getPubKeyInfo(args, success, error) {
        exec(success, error, "Wallet", "getPubKeyInfo", args);
    };

    isAddressValid(args, success, error) {
        var _onSuccess = function(ret: { isValid: boolean }) {
            success(ret.isValid);
        }
        exec(_onSuccess, error, "Wallet", "isAddressValid", args);
    };

    isSubWalletAddressValid(args, success, error) {
        var _onSuccess = function(ret: { isValid: boolean }) {
            success(ret.isValid);
        }
        exec(_onSuccess, error, "Wallet", "isSubWalletAddressValid", args);
    };

    getSupportedChains(args, success, error) {
        exec(success, error, "Wallet", "getSupportedChains", args);
    };

    changePassword(args, success, error) {
        exec(success, error, "Wallet", "changePassword", args);
    };

    resetPassword(args, success, error) {
        exec(success, error, "Wallet", "resetPassword", args);
    };

    //SubWallet

    createAddress(args, success, error) {
        exec(success, error, "Wallet", "createAddress", args);
    };

    getAllAddress(args, success, error) {
        _exec(success, error, "Wallet", "getAllAddress", args);
    };

    getLastAddresses(args, success, error) {
      _exec(success, error, "Wallet", "getLastAddresses", args);
    };

    updateUsedAddress(args, success, error) {
      _exec(success, error, "Wallet", "updateUsedAddress", args);
    };

    getAllPublicKeys(args, success, error) {
        _exec(success, error, "Wallet", "getAllPublicKeys", args);
    };

    createTransaction(args, success, error) {
        exec(success, error, "Wallet", "createTransaction", args);
    };

    signTransaction(args, success, error) {
        exec(success, error, "Wallet", "signTransaction", args);
    };

    getTransactionSignedInfo(args, success, error) {
        _exec(success, error, "Wallet", "getTransactionSignedInfo", args);
    };

    convertToRawTransaction(args, success, error) {
        exec(success, error, "Wallet", "convertToRawTransaction", args);
    };

    //SideChainSubWallet

    createWithdrawTransaction(args, success, error) {
        exec(success, error, "Wallet", "createWithdrawTransaction", args);
    };

    // IDChainSubWallet

    createIdTransaction(args, success, error) {
        exec(success, error, "Wallet", "createIdTransaction", args);
    };

    getAllDID(args, success, error) {
        exec(success, error, "Wallet", "getAllDID", args);
    };

    getAllCID(args, success, error) {
        exec(success, error, "Wallet", "getAllCID", args);
    };

    didSign(args, success, error) {
        exec(success, error, "Wallet", "didSign", args);
    };

    didSignDigest(args, success, error) {
        exec(success, error, "Wallet", "didSignDigest", args);
    };

    verifySignature(args, success, error) {
        exec(success, error, "Wallet", "verifySignature", args);
    };

    getPublicKeyDID(args, success, error) {
        exec(success, error, "Wallet", "getPublicKeyDID", args);
    };

    getPublicKeyCID(args, success, error) {
        exec(success, error, "Wallet", "getPublicKeyCID", args);
    };

    //ETHSideChainSubWallet

    createTransfer(args, success, error) {
        exec(success, error, "Wallet", "createTransfer", args);
    };

    createTransferGeneric(args, success, error) {
        exec(success, error, "Wallet", "createTransferGeneric", args);
    };

    //MainchainSubWallet

    createDepositTransaction(args, success, error) {
        exec(success, error, "Wallet", "createDepositTransaction", args);
    };

    // Vote

    createVoteTransaction(args, success, error) {
        exec(success, error, "Wallet", "createVoteTransaction", args);
    };


    // Producer
    generateProducerPayload(args, success, error) {
        exec(success, error, "Wallet", "generateProducerPayload", args);
    };

    generateCancelProducerPayload(args, success, error) {
        exec(success, error, "Wallet", "generateCancelProducerPayload", args);
    };

    createRegisterProducerTransaction(args, success, error) {
        exec(success, error, "Wallet", "createRegisterProducerTransaction", args);
    };

    createUpdateProducerTransaction(args, success, error) {
        exec(success, error, "Wallet", "createUpdateProducerTransaction", args);
    };

    createCancelProducerTransaction(args, success, error) {
        exec(success, error, "Wallet", "createCancelProducerTransaction", args);
    };

    createRetrieveDepositTransaction(args, success, error) {
        exec(success, error, "Wallet", "createRetrieveDepositTransaction", args);
    };

    getOwnerPublicKey(args, success, error) {
        exec(success, error, "Wallet", "getOwnerPublicKey", args);
    };

    //CRC
    generateCRInfoPayload(args, success, error) {
        _exec(success, error, "Wallet", "generateCRInfoPayload", args);
    };

    generateUnregisterCRPayload(args, success, error) {
        exec(success, error, "Wallet", "generateUnregisterCRPayload", args);
    };

    createRegisterCRTransaction(args, success, error) {
        exec(success, error, "Wallet", "createRegisterCRTransaction", args);
    };

    createUpdateCRTransaction(args, success, error) {
        exec(success, error, "Wallet", "createUpdateCRTransaction", args);
    };

    createUnregisterCRTransaction(args, success, error) {
        exec(success, error, "Wallet", "createUnregisterCRTransaction", args);
    };

    createRetrieveCRDepositTransaction(args, success, error) {
        exec(success, error, "Wallet", "createRetrieveCRDepositTransaction", args);
    };

    getRegisteredCRInfo(args, success, error) {
        exec(success, error, "Wallet", "getRegisteredCRInfo", args);
    };

    CRCouncilMemberClaimNodeDigest(args, success, error) {
        exec(success, error, "Wallet", "CRCouncilMemberClaimNodeDigest", args);
    };

    createCRCouncilMemberClaimNodeTransaction(args, success, error) {
        exec(success, error, "Wallet", "createCRCouncilMemberClaimNodeTransaction", args);
    };

    // Proposal
    proposalOwnerDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalOwnerDigest", args);
    };
    proposalCRCouncilMemberDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalCRCouncilMemberDigest", args);
    };
    calculateProposalHash(args, success, error) {
      exec(success, error, "Wallet", "calculateProposalHash", args);
    };
    createProposalTransaction(args, success, error) {
        exec(success, error, "Wallet", "createProposalTransaction", args);
    };
    proposalReviewDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalReviewDigest", args);
    };
    createProposalReviewTransaction(args, success, error) {
        exec(success, error, "Wallet", "createProposalReviewTransaction", args);
    };

    // Proposal Tracking
    proposalTrackingOwnerDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalTrackingOwnerDigest", args);
    };
    proposalTrackingNewOwnerDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalTrackingNewOwnerDigest", args);
    };
    proposalTrackingSecretaryDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalTrackingSecretaryDigest", args);
    };
    createProposalTrackingTransaction(args, success, error) {
        exec(success, error, "Wallet", "createProposalTrackingTransaction", args);
    };

    // Proposal Secretary General Election
    proposalSecretaryGeneralElectionDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalSecretaryGeneralElectionDigest", args);
    };
    proposalSecretaryGeneralElectionCRCouncilMemberDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalSecretaryGeneralElectionCRCouncilMemberDigest", args);
    };
    createSecretaryGeneralElectionTransaction(args, success, error) {
        exec(success, error, "Wallet", "createSecretaryGeneralElectionTransaction", args);
    };

    // Proposal Change Owner
    proposalChangeOwnerDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalChangeOwnerDigest", args);
    };
    proposalChangeOwnerCRCouncilMemberDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalChangeOwnerCRCouncilMemberDigest", args);
    };
    createProposalChangeOwnerTransaction(args, success, error) {
        exec(success, error, "Wallet", "createProposalChangeOwnerTransaction", args);
    };

    // Proposal Terminate Proposal
    terminateProposalOwnerDigest(args, success, error) {
        exec(success, error, "Wallet", "terminateProposalOwnerDigest", args);
    };
    terminateProposalCRCouncilMemberDigest(args, success, error) {
        exec(success, error, "Wallet", "terminateProposalCRCouncilMemberDigest", args);
    };
    createTerminateProposalTransaction(args, success, error) {
        exec(success, error, "Wallet", "createTerminateProposalTransaction", args);
    };

    // Proposal Withdraw
    proposalWithdrawDigest(args, success, error) {
        exec(success, error, "Wallet", "proposalWithdrawDigest", args);
    };
    createProposalWithdrawTransaction(args, success, error) {
        exec(success, error, "Wallet", "createProposalWithdrawTransaction", args);
    };


    async getERC20TokenList(address: string): Promise<WalletPlugin.ERC20TokenInfo[]> {
        let rawInfo = await execAsPromise<WalletPlugin.ERC20TokenInfo[]>("getERC20TokenList", [address]);
        return rawInfo;
    }
}

var walletManager = new WalletManagerImpl();
export = walletManager;