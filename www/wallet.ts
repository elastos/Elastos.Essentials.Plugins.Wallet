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
    // print(args, success, error) {
    //     exec(success, error, "Wallet", "print", args);
    // };

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

    syncStart(args, success, error) {
      exec(success, error, "Wallet", "syncStart", args);
    };

    syncStop(args, success, error) {
        exec(success, error, "Wallet", "syncStop", args);
    };

    reSync(args, success, error) {
        exec(success, error, "Wallet", "reSync", args);
    };

    getBalanceInfo(args, success, error) {
        exec(success, error, "Wallet", "getBalanceInfo", args);
    };

    getBalance(args, success, error) {
        exec(success, error, "Wallet", "getBalance", args);
    };

    getBalanceWithAddress(args, success, error) {
        exec(success, error, "Wallet", "getBalanceWithAddress", args);
    };

    createAddress(args, success, error) {
        exec(success, error, "Wallet", "createAddress", args);
    };

    getAllAddress(args, success, error) {
        _exec(success, error, "Wallet", "getAllAddress", args);
    };

    getAllPublicKeys(args, success, error) {
        _exec(success, error, "Wallet", "getAllPublicKeys", args);
    };

    createTransaction(args, success, error) {
        exec(success, error, "Wallet", "createTransaction", args);
    };

    getAllUTXOs(args, success, error) {
        _exec(success, error, "Wallet", "getAllUTXOs", args);
    };

    createConsolidateTransaction(args, success, error) {
        exec(success, error, "Wallet", "createConsolidateTransaction", args);
    };

    signTransaction(args, success, error) {
        exec(success, error, "Wallet", "signTransaction", args);
    };

    getTransactionSignedInfo(args, success, error) {
        _exec(success, error, "Wallet", "getTransactionSignedInfo", args);
    };

    publishTransaction(args, success, error) {
        _exec(success, error, "Wallet", "publishTransaction", args);
    };

    getAllTransaction(args, success, error) {
        _exec(success, error, "Wallet", "getAllTransaction", args);
    };

    registerWalletListener(args, success, error) {
        exec(success, error, "Wallet", "registerWalletListener", args);
    };

    removeWalletListener(args, success, error) {
        exec(success, error, "Wallet", "removeWalletListener", args);
    };

    getLastBlockInfo(args, success, error) {
        _exec(success, error, "Wallet", "getLastBlockInfo", args);
    };

    //SideChainSubWallet

    createWithdrawTransaction(args, success, error) {
        exec(success, error, "Wallet", "createWithdrawTransaction", args);
    };

    getGenesisAddress(args, success, error) {
        exec(success, error, "Wallet", "getGenesisAddress", args);
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

    deleteTransfer(args, success, error) {
        exec(success, error, "Wallet", "deleteTransfer", args);
    };

    getTokenTransactions(args, success, error) {
        _exec(success, error, "Wallet", "getTokenTransactions", args);
    };

    //MainchainSubWallet

    createDepositTransaction(args, success, error) {
        exec(success, error, "Wallet", "createDepositTransaction", args);
    };

    // Vote
    createVoteProducerTransaction(args, success, error) {
        exec(success, error, "Wallet", "createVoteProducerTransaction", args);
    };

    createVoteCRTransaction(args, success, error) {
        exec(success, error, "Wallet", "createVoteCRTransaction", args);
    };

    createVoteCRCProposalTransaction(args, success, error) {
        exec(success, error, "Wallet", "createVoteCRCProposalTransaction", args);
    };
    createImpeachmentCRCTransaction(args, success, error) {
        exec(success, error, "Wallet", "createImpeachmentCRCTransaction", args);
    };

    getVotedProducerList(args, success, error) {
        exec(success, error, "Wallet", "getVotedProducerList", args);
    };

    getVotedCRList(args, success, error) {
        exec(success, error, "Wallet", "getVotedCRList", args);
    };

    getVoteInfo(args, success, error) {
        exec(success, error, "Wallet", "getVoteInfo", args);
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

    getRegisteredProducerInfo(args, success, error) {
        exec(success, error, "Wallet", "getRegisteredProducerInfo", args);
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

    //////////////////////////////////////////////////
    /*               Backup and restore             */
    //////////////////////////////////////////////////

    async getBackupInfo(masterWalletID: string): Promise<WalletPlugin.BackupInfo> {
        let rawInfo = await execAsPromise<WalletPlugin.BackupInfo>("getBackupInfo", [masterWalletID]);
        return BackupInfoImpl.fromJson(rawInfo);
    }

    async getBackupFile(masterWalletID: string, fileName: string): Promise<WalletPlugin.BackupFileReader> {
        let rawReader = await execAsPromise<any>("getBackupFile", [masterWalletID, fileName]);
        return BackupFileReaderImpl.fromJson(rawReader);
    }

    async restoreBackupFile(masterWalletID: string, fileName: string): Promise<WalletPlugin.BackupFileWriter> {
        let rawWriter = await execAsPromise<any>("restoreBackupFile", [masterWalletID, fileName]);
        return BackupFileWriterImpl.fromJson(rawWriter);
    }
}

class BackupInfoImpl implements WalletPlugin.BackupInfo {
    ELADatabase: WalletPlugin.BackupFile;
    IDChainDatabase: WalletPlugin.BackupFile;
    ETHChainDatabase: WalletPlugin.BackupFile;

    static fromJson(json: any) {
        let backupInfo = new BackupInfoImpl();
        Object.assign(backupInfo, json);

        // Convert a few fields
        if ("ELADatabase" in json) {
            backupInfo.ELADatabase.lastModified = new Date(json.ELADatabase.lastModified);
        }
        if ("IDChainDatabase" in json) {
            backupInfo.IDChainDatabase.lastModified = new Date(json.IDChainDatabase.lastModified);
        }
        if ("ETHChainDatabase" in json) {
            backupInfo.ETHChainDatabase.lastModified = new Date(json.ETHChainDatabase.lastModified);
        }

        return backupInfo;
    }
}

class BackupFileReaderImpl implements WalletPlugin.BackupFileReader {
    objectId: string;

    async read(bytesCount: number): Promise<Uint8Array> {
        // Cordova automatically converts Uint8Array to a encoded base64 string in the direction JS->Native.
        // But it does not convert from base64 to Uint8Array in the other direction. So we do this manually.
        let readData = await execAsPromise<string>("backupFileReader_read", [this.objectId, bytesCount]);
        if (!readData)
            return null;

        return new Base64Binary().decode(readData);
    }

    close() {
        return execAsPromise<void>("backupFileReader_close", [this.objectId]);
    }

    static fromJson(json: any): BackupFileReaderImpl {
        if (!json)
            return null;

        let result = new BackupFileReaderImpl();
        Object.assign(result, json);
        return result;
    }
}

class BackupFileWriterImpl implements WalletPlugin.BackupFileWriter {
    objectId: string;

    write(bytes: Uint8Array): Promise<void> {
        return execAsPromise<void>("backupFileWriter_write", [this.objectId, bytes.buffer]);
    }
    close() {
        return execAsPromise<void>("backupFileWriter_close", [this.objectId, ]);
    }

    static fromJson(json: any): BackupFileWriterImpl {
        if (!json)
            return null;

        let result = new BackupFileWriterImpl();
        Object.assign(result, json);
        return result;
    }
}

/**
 * Helper for base64 conversions.
 * Converted to TS from the original JS code at https://github.com/niklasvh/base64-arraybuffer/blob/master/lib/base64-arraybuffer.js
 */
class Base64Binary {
    private chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    private lookup: Uint8Array = null;

    constructor() {
        // Use a lookup table to find the index.
        this.lookup = new Uint8Array(256);
        for (var i = 0; i < this.chars.length; i++) {
            this.lookup[this.chars.charCodeAt(i)] = i;
        }
    }

    encode(arraybuffer: ArrayBuffer): string {
      var bytes = new Uint8Array(arraybuffer), i, len = bytes.length, base64 = "";

      for (i = 0; i < len; i+=3) {
        base64 += this.chars[bytes[i] >> 2];
        base64 += this.chars[((bytes[i] & 3) << 4) | (bytes[i + 1] >> 4)];
        base64 += this.chars[((bytes[i + 1] & 15) << 2) | (bytes[i + 2] >> 6)];
        base64 += this.chars[bytes[i + 2] & 63];
      }

      if ((len % 3) === 2) {
        base64 = base64.substring(0, base64.length - 1) + "=";
      } else if (len % 3 === 1) {
        base64 = base64.substring(0, base64.length - 2) + "==";
      }

      return base64;
    };

    decode(base64: string): Uint8Array {
      var bufferLength = base64.length * 0.75, len = base64.length, i, p = 0, encoded1, encoded2, encoded3, encoded4;

      if (base64[base64.length - 1] === "=") {
        bufferLength--;
        if (base64[base64.length - 2] === "=") {
          bufferLength--;
        }
      }

      var arraybuffer = new ArrayBuffer(bufferLength),
      bytes = new Uint8Array(arraybuffer);

      for (i = 0; i < len; i+=4) {
        encoded1 = this.lookup[base64.charCodeAt(i)];
        encoded2 = this.lookup[base64.charCodeAt(i+1)];
        encoded3 = this.lookup[base64.charCodeAt(i+2)];
        encoded4 = this.lookup[base64.charCodeAt(i+3)];

        bytes[p++] = (encoded1 << 2) | (encoded2 >> 4);
        bytes[p++] = ((encoded2 & 15) << 4) | (encoded3 >> 2);
        bytes[p++] = ((encoded3 & 3) << 6) | (encoded4 & 63);
      }

      return new Uint8Array(arraybuffer);
    };
}

var walletManager = new WalletManagerImpl();
export = walletManager;