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

/**
* This is about Wallet which can only be used by wallet application by default.
* However, you can change this by editing the group.json correctly.
* <br><br>
* Please use 'Wallet' as the plugin name in the manifest.json if you want to use
* this facility. Additionally, you need to make sure you have permission(granted
* in the group.json) to use it.
* <br><br>
* Usage:
* <br>
* declare let walletManager: WalletPlugin.WalletManager;
*/

declare module WalletPlugin {
    const enum VoteType {
        Delegate,
        CRC,
        CRCProposal,
        CRCImpeachment,
        Max,
    }

    const enum CRCProposalType {
        normal = 0x0000,
        elip = 0x0100,
        flowElip = 0x0101,
        infoElip = 0x0102,
        mainChainUpgradeCode = 0x0200,
        sideChainUpgradeCode = 0x0300,
        registerSideChain = 0x0301,
        secretaryGeneral = 0x0400,
        changeSponsor = 0x0401,
        closeProposal = 0x0402,
        dappConsensus = 0x0500,
        maxType
    }

    const enum CRCProposalTrackingType {
        common = 0x00,
        progress = 0x01,
        progressReject = 0x02,
        terminated = 0x03,
        proposalLeader = 0x04,
        appropriation = 0x05,
        maxType
    }

    const enum EthereumAmountUnit {
        TOKEN_DECIMAL = 0,
        TOKEN_INTEGER = 1,

        ETHER_WEI = 0,
        ETHER_GWEI = 3,
        ETHER_ETHER = 6,
    }

    const enum LogType {
        TRACE = "trace",
        DEBUG = 'debug',
        INFO = 'info',
        WARNING = 'warning',
        ERROR = 'error',
        CRITICAL = 'critical',
        OFF = 'off',
    }

    const enum MnemonicLanguage {
        CHINESE = 'chinese',
        ENGLISH = "english",
    }

    const enum NetworkType {
        MAINNET = "MainNet",
        TESTNET = 'TestNet',
        REGNET = 'RegTest',
        PRIVATENET = 'PrvNet',
    }

    interface WalletManager {
        //MasterWalletManager

        /**
         * Initialize the MasterWalletManager.
         */
        init(args, success, error);

        /**
         * Generate a mnemonic by random entropy. We support English, Chinese, French, Italian, Japanese, and
         *     Spanish 6 types of mnemonic currently.
         * @param language specify mnemonic language.
         * @return a random mnemonic.
         */
        generateMnemonic(args, success, error);

        /**
         * Create a new master wallet by mnemonic and phrase password, or return existing master wallet if current master wallet manager has the master wallet id.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param mnemonic use to generate seed which deriving the master private key and chain code.
         * @param phrasePassword combine with random seed to generate root key and chain code. Phrase password can be empty or between 8 and 128, otherwise will throw invalid argument exception.
         * @param payPassword use to encrypt important things(such as private key) in memory. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @param singleAddress if true, the created wallet will only contain one address, otherwise wallet will manager a chain of addresses.
         * @return If success will return a pointer of master wallet interface.
         */
        createMasterWallet(args, success, error);

        /**
         * Create a multi-sign master wallet by related co-signers, or return existing master wallet if current master wallet manager has the master wallet id. Note this creating method generate an readonly multi-sign account which can not append sign into a transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param cosigners JSON array of signer's extend public key. Such as: ["xpub6CLgvYFxzqHDJCWyGDCRQzc5cwCFp4HJ6QuVJsAZqURxmW9QKWQ7hVKzZEaHgCQWCq1aNtqmE4yQ63Yh7frXWUW3LfLuJWBtDtsndGyxAQg", "xpub6CWEYpNZ3qLG1z2dxuaNGz9QQX58wor9ax8AiKBvRytdWfEifXXio1BgaVcT4t7ouP34mnabcvpJLp9rPJPjPx2m6izpHmjHkZAHAHZDyrc"]
         * @param m specify minimum count of signature to accomplish related transaction.
         * @param singleAddress if true, the created wallet will only contain one address, otherwise wallet will manager a chain of addresses.
         * @param compatible if true, will compatible with web multi-sign wallet.
         * @param timestamp the value of time in seconds since 1970-01-01 00:00:00. It means the time when the wallet contains the first transaction.
         * @return If success will return a pointer of master wallet interface.
         */
        createMultiSignMasterWallet(args, success, error);

        /**
         * Create a multi-sign master wallet by private key and related co-signers, or return existing master wallet if current master wallet manager has the master wallet id.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param xprv root extend private key of wallet.
         * @param payPassword use to encrypt important things(such as private key) in memory. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @param cosigners JSON array of signer's extend public key. Such as: ["xpub6CLgvYFxzqHDJCWyGDCRQzc5cwCFp4HJ6QuVJsAZqURxmW9QKWQ7hVKzZEaHgCQWCq1aNtqmE4yQ63Yh7frXWUW3LfLuJWBtDtsndGyxAQg", "xpub6CWEYpNZ3qLG1z2dxuaNGz9QQX58wor9ax8AiKBvRytdWfEifXXio1BgaVcT4t7ouP34mnabcvpJLp9rPJPjPx2m6izpHmjHkZAHAHZDyrc"]
         * @param m specify minimum count of signature to accomplish related transaction.
         * @param singleAddress if true, the created wallet will only contain one address, otherwise wallet will manager a chain of addresses.
         * @param compatible if true, will compatible with web multi-sign wallet.
         * @param timestamp the value of time in seconds since 1970-01-01 00:00:00. It means the time when the wallet contains the first transaction.
         * @return If success will return a pointer of master wallet interface.
         */
        createMultiSignMasterWalletWithPrivKey(args, success, error);

        /**
         * Create a multi-sign master wallet by private key and related co-signers, or return existing master wallet if current master wallet manager has the master wallet id.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param mnemonic use to generate seed which deriving the master private key and chain code.
         * @param passphrase combine with random seed to generate root key and chain code. Phrase password can be empty or between 8 and 128, otherwise will throw invalid argument exception.
         * @param payPassword use to encrypt important things(such as private key) in memory. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @param cosigners JSON array of signer's extend public key. Such as: ["xpub6CLgvYFxzqHDJCWyGDCRQzc5cwCFp4HJ6QuVJsAZqURxmW9QKWQ7hVKzZEaHgCQWCq1aNtqmE4yQ63Yh7frXWUW3LfLuJWBtDtsndGyxAQg", "xpub6CWEYpNZ3qLG1z2dxuaNGz9QQX58wor9ax8AiKBvRytdWfEifXXio1BgaVcT4t7ouP34mnabcvpJLp9rPJPjPx2m6izpHmjHkZAHAHZDyrc"]
         * @param m specify minimum count of signature to accomplish related transactions.
         * @param singleAddress if true, the created wallet will only contain one address, otherwise wallet will manager a chain of addresses.
         * @param compatible if true, will compatible with web multi-sign wallet.
         * @param timestamp the value of time in seconds since 1970-01-01 00:00:00. It means the time when the wallet contains the first transaction.
         * @return If success will return a pointer of master wallet interface.
         */
        createMultiSignMasterWalletWithMnemonic(args, success, error);


        /**
         * Import master wallet by key store file.
         * @param masterWalletId is the unique identification of a master wallet object.
         * @param keystoreContent specify key store content in json format.
         * @param backupPassword use to encrypt key store file. Backup password should between 8 and 128, otherwise will throw invalid argument exception.
         * @param payPassword use to encrypt important things(such as private key) in memory. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @return If success will return a pointer of master wallet interface.
         */
        importWalletWithKeystore(args, success, error);

        /**
         * Import master wallet by mnemonic.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param mnemonic for importing the master wallet.
         * @param phrasePassword combine with mnemonic to generate root key and chain code. Phrase password can be empty or between 8 and 128, otherwise will throw invalid argument exception.
         * @param payPassword use to encrypt important things(such as private key) in memory. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @param singleAddress singleAddress if true created wallet will have only one address inside, otherwise sub wallet will manager a chain of addresses for security.
         * @return If success will return a pointer of master wallet interface.
         */
        importWalletWithMnemonic(args, success, error);

        /**
         * Get manager existing master wallets.
         * @return existing master wallet array.
         */
        getAllMasterWallets(args, success, error);

        /**
         * Destroy a master wallet.
         * @param masterWalletID A pointer of master wallet interface create or imported by wallet factory object.
         */
        destroyWallet(args, success, error);

        /**
         * Get version
         * @return SPV SDK version
         */
        getVersion(args, success, error);

        /**
         * Set log level
         *  @param level can be value of: "trace", "debug", "info", "warning", "error", "critical", "off"
         */
        setLogLevel(args, success, error);

        /**
         * Set network type, config and rpc url.
         * You should call this api before initMasterWalletManager.
         *  @param type can be value of: "MainNet", "TestNet", "RegTest", "PrvNet"
         *  @param config The config of the private network, set """ for other network".
         *  @param jsonrpcUrl The url of json rpc.
         *  @param apimiscUrl The url of api misc.
         */
        setNetwork(args, success, error);

        //MasterWallet

        /**
         * Get basic info of master wallet
         * @param masterWalletID is the unique identification of a master wallet object.
         * @return basic information. Such as:
         * {"M":1,"N":1,"Readonly":false,"SingleAddress":false,"Type":"Standard", "HasPassPhrase": false}
         */
        getMasterWalletBasicInfo(args, success, error);

        /**
         * Get wallet existing sub wallets.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @return existing sub wallets by array.
         */
        getAllSubWallets(args, success, error);

        /**
         * Create a sub wallet of chainID.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return If success will return a pointer of sub wallet interface.
         */
        createSubWallet(args, success, error);

        /**
         * Export Keystore of the current wallet in JSON format.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param backupPassword use to decrypt key store file. Backup password should between 8 and 128, otherwise will throw invalid argument exception.
         * @param payPassword use to decrypt and generate mnemonic temporarily. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @return If success will return key store content in json format.
         */
        exportWalletWithKeystore(args, success, error);

        /**
         * Export mnemonic of the current wallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param payPassword use to decrypt and generate mnemonic temporarily. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @return If success will return the mnemonic of master wallet.
         */
        exportWalletWithMnemonic(args, success, error);

        /**
         * Verify passphrase and pay password whether same as current wallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param passphrase password for  mnemonic. Passphrase should between 8 and 128.
         * @param payPassword password for transaction. Pay password should between 8 and 128.
         * @return If success will return the mnemonic of master wallet.
         */
        verifyPassPhrase(args, success, error);

        /**
         * Verify pay password whether same as current wallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param payPassword password for transaction. Pay password should between 8 and 128.
         * @return If success will return the mnemonic of master wallet.
         */
        verifyPayPassword(args, success, error);

        /**
         * Destroy a sub wallet created by the master wallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID chain ID of subWallet.
         */
        destroySubWallet(args, success, error);

        /**
         * Get public key info.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @return public key info.
         */
        getPubKeyInfo(args, success, error);

        /**
         * Verify an address which can be normal, multi-sign, cross chain, or id address.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param address to be verified.
         * @return True if valid, otherwise return false.
         */
        isAddressValid(args, success, error);

        /**
         * Verify an address which can be normal, multi-sign, cross chain, id address or ETHSC.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID chain id of subwallet
         * @param address address of subwallet
         * @return True if valid, otherwise return false.
         */
        isSubWalletAddressValid(args, success, error);

        /**
         * Get all chain ids of supported chains.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @return a list of chain id.
         */
        getSupportedChains(args, success, error);

        /**
         * Change pay password which encrypted private key and other important data in memory.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param oldPassword the old pay password.
         * @param newPassword new pay password.
         */
        changePassword(args, success, error);

        /**
         * Reset payment password of current wallet
         * @param mnemonic mnemonic
         * @param passphrase passphrase
         * @param newPassword New password will be set.
         */
        resetPassword(args, success, error);


        //SubWallet

        /**
         * Start sync of P2P network
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         */
        syncStart(args, success, error);

        /**
         * Stop sync of P2P network
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         */
        syncStop(args, success, error);

        /**
         * Will delete all Merkle blocks and all transactions except the private key.
         * And then resync from the beginning.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         */
        reSync(args, success, error);

        /**
         * Get balances of all addresses in json format.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return balances of all addresses in json format.
         */
        getBalanceInfo(args, success, error);

        /**
         * Get sum of balances of all addresses according to balance type.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return sum of balances.
         */
        getBalance(args, success, error);

        /**
         * Get balance of only the specified address.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param address is one of addresses created by current sub wallet.
         * @return balance of specified address.
         */
        getBalanceWithAddress(args, success, error);

        /**
         * Create a new address or return existing unused address. Note that if create the sub wallet by setting the singleAddress to true, will always return the single address.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return a new address or existing unused address.
         */
        createAddress(args, success, error);

        /**
         * Get all created addresses in json format. The parameters of start and count are used for purpose of paging.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param start specify start index of all addresses list.
         * @param count specify count of addresses we need.
         * @return addresses in JSON format.
         *
         * example:
         * {
         *     "Addresses": ["EYMVuGs1FscpgmghSzg243R6PzPiszrgj7", "EJuHg2CdT9a9bqdKUAtbrAn6DGwXtKA6uh"],
         *     "MaxCount": 100
         * }
         */
        getAllAddress(args, success, error);

        /**
         * Get all created public key list in JSON format. The parameters of start and count are used for the purpose of paging.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param start to specify start index of all public key list.
         * @param count specifies the count of public keys we need.
         * @return public keys in json format.
         */
        getAllPublicKeys(args, success, error);

        /**
         * Create a normal transaction and return the content of transaction in json format.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress specify which address we want to spend, or just input empty string to let wallet choose UTXOs automatically.
         * @param targetAddress specify which address we want to send.
         * @param amount specify amount we want to send. "-1" means max.
         * @param memo input memo attribute for describing.
         * @return If success return the content of transaction in json format.
         */
        createTransaction(args, success, error);

        /**
         * Get all UTXO list. Include locked and pending and deposit utxos.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param start specify start index of all utxos list.
         * @param count specify count of utxos we need.
         * @param address to filter the specify address's utxos. If empty, all utxo of all addresses wil be returned.
         * @return return all utxo in json format
         */
        getAllUTXOs(args, success, error);

        /**
         * Create a transaction to combine as many UTXOs as possible until transaction size reaches the max size.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param memo input memo attribute for describing.
         * @return If success return the content of transaction in json format.
         */
        createConsolidateTransaction(args, success, error);

        /**
         * Sign a transaction or append sign to a multi-sign transaction and return the content of transaction in json format.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param tx transaction created by Create*Transaction().
         * @param payPassword use to decrypt the root private key temporarily. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @return If success return the content of transaction in json format.
         */
        signTransaction(args, success, error);

        /**
         * Get signers already signed specified transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param tx a signed transaction to find signed signers.
         * @return Signed signers in json format. An example of result will be displayed as follows:
         *
         * [{"M":3,"N":4,"SignType":"MultiSign","Signers":["02753416fc7c1fb43c91e29622e378cd16243b53577ec971c6c3624a775722491a","0370a77a257aa81f46629865eb8f3ca9cb052fcfd874e8648cfbea1fbf071b0280","030f5bdbee5e62f035f19153c5c32966e0fc72e419c2b4867ba533c43340c86b78"]}]
         * or
         * [{"SignType":"Standard","Signers":["0207d8bc14c4bdd79ea4a30818455f705bcc9e17a4b843a5f8f4a95aa21fb03d77"]},{"SignType":"Standard","Signers":["02a58d1c4e4993572caf0133ece4486533261e0e44fb9054b1ea7a19842c35300e"]}]
         *
         */
        getTransactionSignedInfo(args, success, error);

        /**
         * Publish a transaction to p2p network.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param tx signed transaction.
         * @return Sent result in json format.
         */
        publishTransaction(args, success, error);

        /**
         * Get all qualified normal transactions sorted by descent (newest first).
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param start specify start index of all transactions list.
         * @param count specify count of transactions we need.
         * @param txid transaction ID to be filtered.
         * @return All qualified transactions in json format.
         * {"MaxCount":3,"Transactions":[{"Amount":"20000","ConfirmStatus":"6+","Direction":"Received","Height":172570,"Status":"Confirmed","Timestamp":1557910458,"TxHash":"ff454532e57837cbe04f56a7e43f4209b5eb61d5d2a43a016a769c60d21125b6","Type":6},{"Amount":"10000","ConfirmStatus":"6+","Direction":"Received","Height":172569,"Status":"Confirmed","Timestamp":1557909659,"TxHash":"7253b2cefbac794b621b0080f0f5a4c27d5c91f65c83da75aad615062c42ac5a","Type":6},{"Amount":"100000","ConfirmStatus":"6+","Direction":"Received","Height":172300,"Status":"Confirmed","Timestamp":1557809019,"TxHash":"7e53bb8fe1617bdb57f7346bcf7d2e9dfa6b5d3f3524d0695046389bea79dcd9","Type":6}]}
         */
        getAllTransaction(args, success, error);

        /**
         * Add a sub wallet callback object listened to current sub wallet.
         */
        registerWalletListener(args, success, error);

        /**
         * Remove a sub wallet callback object listened to current sub wallet.
         */
        removeWalletListener(args, success, error);

        /**
         * Get last block information including "Height", "Timestamp", "Hash"
         * @return information in json format.
         */
        getLastBlockInfo(args, success, error);


        // sideChainSubWallet

        /**
         * Create a withdraw transaction and return the content of transaction in json format. Note that \p amount should greater than sum of \p so that we will leave enough fee for mainchain.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress specify which address we want to spend, or just input empty string to let wallet choose UTXOs automatically.
         * @param amount specify amount we want to send.
         * @param mainChainAddress mainchain address.
         * @param memo input memo attribute for describing.
         * @return If success return the content of transaction in json format.
         */
        createWithdrawTransaction(args, success, error);

        /**
         * Get genesis address of the side chain, the address is a special address will be set to toAddress in CreateDepositTransaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return genesis address of the side chain.
         */
        getGenesisAddress(args, success, error);

        // IDChainSubWallet

        /**
         * Create a id transaction and return the content of transaction in json format, this is a special transaction to register id related information on id chain.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payloadJson is payload for register id related information in json format, the content of payload should have Id, Path, DataHash, Proof, and Sign.
         * @param memo input memo attribute for describing.
         * @return If success return the content of transaction in json format.
         */
        createIdTransaction(args, success, error);

        /**
         * Get all DID derived of current subwallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param start specify start index of all DID list.
         * @param count specify count of DID we need.
         * @return If success return all DID in JSON format.
         *
         * example:
         * GetAllDID(0, 3) will return below
         * {
         *     "DID": ["iZDgaZZjRPGCE4x8id6YYJ158RxfTjTnCt", "iPbdmxUVBzfNrVdqJzZEySyWGYeuKAeKqv", "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP"],
         *     "MaxCount": 100
         * }
         */
        getAllDID(args, success, error);

        /**
         * Get all CID derived of current subwallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param start specify start index of all CID list.
         * @param count specify count of CID we need.
         * @return If success return all CID in JSON format.
         *
         * example:
         * GetAllCID(0, 3) will return below
         * {
         *     "CID": ["iZDgaZZjRPGCE4x8id6YYJ158RxfTjTnCt", "iPbdmxUVBzfNrVdqJzZEySyWGYeuKAeKqv", "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP"],
         *     "MaxCount": 100
         * }
         */
        getAllCID(args, success, error);

        /**
         * Sign message with private key of did.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param did will sign the message with public key of this did.
         * @param message to be signed.
         * @param payPassword pay password.
         * @return If success, signature will be returned.
         */
        didSign(args, success, error);

        /**
         * Sign message with private key of did.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param did will sign the message with public key of this did.
         * @param digest hex string of sha256
         * @param payPassword pay password.
         * @return If success, signature will be returned.
         */
        didSignDigest(args, success, error);

        /**
         * Verify signature with specify public key
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param publicKey public key.
         * @param message message to be verified.
         * @param signature signature to be verified.
         * @return true or false.
         */
        verifySignature(args, success, error);

        /**
         * Get DID by public key
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param pubkey public key
         * @return did string
         */
        getPublicKeyDID(args, success, error);

        /**
         * Get CID by public key
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param pubkey public key
         * @return cid string
         */
        getPublicKeyCID(args, success, error);

        //ETHSideChainSubWallet

        /**
         *
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param targetAddress
         * @param amount
         * @param amountUnit
         * @return
         */
        createTransfer(args, success, error);

        /**
         *
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param targetAddress
         * @param amount
         * @param amountUnit
         * @param gasPrice
         * @param gasPriceUnit
         * @param gasLimit
         * @param data
         * @return
         */
        createTransferGeneric(args, success, error);

        /**
         *
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param tx  The transaction in JSON format.(must have ID)
         * @return
         */
        deleteTransfer(args, success, error);

        /**
         *
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param start
         * @param count
         * @param txid
         * @param tokenSymbol
         * @return
         */
        getTokenTransactions(args, success, error);

        //MainchainSubWallet

        /**
         * Deposit token from the main chain to side chains, such as ID chain or token chain, etc.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress      If this address is empty, wallet will pick available UTXO automatically.
         *                         Otherwise, wallet will pick UTXO from the specific address.
         * @param sideChainID      Chain id of the side chain.
         * @param amount           The amount that will be deposit to the side chain.
         * @param sideChainAddress Receive address of side chain.
         * @memo                   Remarks string. Can be empty string.
         * @return                 The transaction in JSON format to be signed and published.
         */
        createDepositTransaction(args, success, error);

        //////////////////////////////////////////////////
        /*                      Vote                    */
        //////////////////////////////////////////////////

        /**
         * Create vote transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param stake        Vote amount in sela. "-1" means max.
         * @param publicKeys   Public keys array in JSON format.
         * @param memo         Remarks string. Can be empty string.
         * @invalidCandidates  invalid candidate except current vote candidates. Such as:
                                  [
                                      {
                                        "Type":"CRC",
                                        "Candidates":[
                                            "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
                                            "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP",
                                            "iYMVuGs1FscpgmghSzg243R6PzPiszrgj7"
                                        ]
                                    },
                                    {
                                        "Type":"Delegate",
                                        "Candidates":[
                                            "02848A8F1880408C4186ED31768331BC9296E1B0C3EC7AE6F11E9069B16013A9C5",
                                            "02775B47CCB0808BA70EA16800385DBA2737FDA090BB0EBAE948DD16FF658CA74D",
                                            "03E5B45B44BB1E2406C55B7DD84B727FAD608BA7B7C11A9C5FFBFEE60E427BD1DA"
                                        ]
                                    }
                                ]
         * @return             The transaction in JSON format to be signed and published. Note: "DropVotes" means the old vote will be dropped.
         */
        createVoteProducerTransaction(args, success, error);

        /**
         * Create vote cr transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param votes        Candidate code and votes in JSON format. Such as:
         *                     {
         *                          "iYMVuGs1FscpgmghSzg243R6PzPiszrgj7": "100000000",
         *                          "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP": "200000000"
         *                     }
         * @param memo         Remarks string. Can be empty string.
         * @param invalidCandidates  invalid candidate except current vote candidates. Such as:
                                  [
                                      {
                                        "Type":"CRC",
                                        "Candidates":[
                                            "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
                                            "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP",
                                            "iYMVuGs1FscpgmghSzg243R6PzPiszrgj7"
                                        ]
                                    },
                                    {
                                        "Type":"Delegate",
                                        "Candidates":[
                                            "02848A8F1880408C4186ED31768331BC9296E1B0C3EC7AE6F11E9069B16013A9C5",
                                            "02775B47CCB0808BA70EA16800385DBA2737FDA090BB0EBAE948DD16FF658CA74D",
                                            "03E5B45B44BB1E2406C55B7DD84B727FAD608BA7B7C11A9C5FFBFEE60E427BD1DA"
                                        ]
                                    }
                                ]
         * @return             The transaction in JSON format to be signed and published. Note: "DropVotes" means the old vote will be dropped.
         */
        createVoteCRTransaction(args, success, error);

        /**
         * Create vote crc proposal transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param votes        Proposal hash and votes in JSON format. Such as:
         *                     {
         *                          "109780cf45c7a6178ad674ac647545b47b10c2c3e3b0020266d0707e5ca8af7c": "100000000",
         *                          "92990788d66bf558052d112f5498111747b3e28c55984d43fed8c8822ad9f1a7": "200000000"
         *                     }
         * @param memo         Remarks string. Can be empty string.
         * @param invalidCandidates  invalid candidate except current vote candidates. Such as:
                                  [
                                      {
                                        "Type":"CRC",
                                        "Candidates":[
                                            "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
                                            "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP",
                                            "iYMVuGs1FscpgmghSzg243R6PzPiszrgj7"
                                        ]
                                    },
                                    {
                                        "Type":"Delegate",
                                        "Candidates":[
                                            "02848A8F1880408C4186ED31768331BC9296E1B0C3EC7AE6F11E9069B16013A9C5",
                                            "02775B47CCB0808BA70EA16800385DBA2737FDA090BB0EBAE948DD16FF658CA74D",
                                            "03E5B45B44BB1E2406C55B7DD84B727FAD608BA7B7C11A9C5FFBFEE60E427BD1DA"
                                        ]
                                    }
                                ]
         * @return             The transaction in JSON format to be signed and published. Note: "DropVotes" means the old vote will be dropped.
         */
        createVoteCRCProposalTransaction(args, success, error);

        /**
         * Create impeachment crc transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param votes        CRC did and votes in JSON format. Such as:
         *                     {
         *                          "innnNZJLqmJ8uKfVHKFxhdqVtvipNHzmZs": "100000000",
         *                          "iZFrhZLetd6i6qPu2MsYvE2aKrgw7Af4Ww": "200000000"
         *                     }
         * @param memo         Remarks string. Can be empty string.
         * @param invalidCandidates  invalid candidate except current vote candidates. Such as:
                                  [
                                      {
                                        "Type":"CRC",
                                        "Candidates":[
                                            "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
                                            "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP",
                                            "iYMVuGs1FscpgmghSzg243R6PzPiszrgj7"
                                        ]
                                    },
                                    {
                                        "Type":"Delegate",
                                        "Candidates":[
                                            "02848A8F1880408C4186ED31768331BC9296E1B0C3EC7AE6F11E9069B16013A9C5",
                                            "02775B47CCB0808BA70EA16800385DBA2737FDA090BB0EBAE948DD16FF658CA74D",
                                            "03E5B45B44BB1E2406C55B7DD84B727FAD608BA7B7C11A9C5FFBFEE60E427BD1DA"
                                        ]
                                    }
                                ]
         * @return             The transaction in JSON format to be signed and published. Note: "DropVotes" means the old vote will be dropped.
         */
        createImpeachmentCRCTransaction(args, success, error);

        /**
         * Get vote information of current wallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return Vote information in JSON format. The key is the public key, and the value is the stake. Such as:
         * {
         *      "02848A8F1880408C4186ED31768331BC9296E1B0C3EC7AE6F11E9069B16013A9C5": "10000000",
         *      "02775B47CCB0808BA70EA16800385DBA2737FDA090BB0EBAE948DD16FF658CA74D": "200000000",
         *      "03E5B45B44BB1E2406C55B7DD84B727FAD608BA7B7C11A9C5FFBFEE60E427BD1DA": "5000000000"
         * }
         */
        getVotedProducerList(args, success, error);

        /**
         * Get CR vote information of current wallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return Vote information in JSON format. The key is the public key, and the value is the stake. Such as:
         * {
         *      "iYMVuGs1FscpgmghSzg243R6PzPiszrgj7": "10000000",
         *      "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP": "200000000"
         * }
         */
        getVotedCRList(args, success, error);

        /**
         * Get summary or details of all types of votes
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @type if the type is empty, a summary of all types of votes will return. Otherwise, the details of the specified type will return.
         * @return vote info in JSON format. Such as:
         *
         * summary:
         *  [
         *      {"Type": "Delegate", "Amount": "12345", "Timestamp": 1560888482, "Expiry": null},
         *      {"Type": "CRC", "Amount": "56789", "Timestamp": 1560888482, "Expiry": 1561888000}
         *  ]
         *
         * details:
         *  [{
         *      "Type": "Delegate",
         *      "Amount": "200000000",
         *      "Timestamp": 1560888482,
         *      "Expiry": null,
         *      "Votes": {"02848A8F1880408C4186ED31768331BC9296E1B0C3EC7AE6F11E9069B16013A9C5": "10000000","02775B47CCB0808BA70EA16800385DBA2737FDA090BB0EBAE948DD16FF658CA74D": "200000000"}
         *  },
         *  {
         *      ...
         *  }]
         * or:
         *  [{
         *      "Type": "CRC",
         *      "Amount": "300000000",
         *      "Timestamp": 1560888482,
         *      "Expiry": null,
         *      "Votes": {"iYMVuGs1FscpgmghSzg243R6PzPiszrgj7": "10000000","iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP": "200000000"}
         *  },
         *  {
         *      ...
         *  }]
         */
        getVoteInfo(args, success, error);

        //////////////////////////////////////////////////
        /*                    Producer                  */
        //////////////////////////////////////////////////

        /**
         * Generate payload for registering or updating producer.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param ownerPublicKey The public key to identify a producer. Can't change later. The producer reward will
         *                       be sent to address of this public key.
         * @param nodePublicKey  The public key to identify a node. Can be update
         *                       by CreateUpdateProducerTransaction().
         * @param nickName       Nickname of producer.
         * @param url            URL of producer.
         * @param ipAddress      IP address of node. This argument is deprecated.
         * @param location       Location code.
         * @param payPasswd      Pay password is using for signing the payload with the owner private key.
         *
         * @return               The payload in JSON format.
         */
        generateProducerPayload(args, success, error);

        /**
         * Generate payaload for unregistering producer.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param ownerPublicKey The public key to identify a producer.
         * @param payPasswd      Pay password is using for signing the payload with the owner private key.
         *
         * @return               The payload in JSON format.
         */
        generateCancelProducerPayload(args, success, error);

        /**
         * Create register producer transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param payload      Generate by GenerateProducerPayload().
         * @param amount       Amount must lager than 500,000,000,000 sela
         * @param memo         Remarks string. Can be empty string.
         * @return             The transaction in JSON format to be signed and published.
         */
        createRegisterProducerTransaction(args, success, error);

        /**
         * Create update producer transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param payload      Generate by GenerateProducerPayload().
         * @param memo         Remarks string. Can be empty string.
         *
         * @return             The transaction in JSON format to be signed and published.
         */
        createUpdateProducerTransaction(args, success, error);

        /**
         * Create cancel producer transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param payload      Generate by GenerateCancelProducerPayload().
         * @param memo         Remarks string. Can be empty string.
         * @return             The transaction in JSON format to be signed and published.
         */
        createCancelProducerTransaction(args, success, error);

        /**
         * Create retrieve deposit transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param amount     The available amount to be retrieved back.
         * @param memo       Remarks string. Can be empty string.
         *
         * @return           The transaction in JSON format to be signed and published.
         */
        createRetrieveDepositTransaction(args, success, error);

        /**
         * Get owner public key.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return Owner public key.
         */
        getOwnerPublicKey(args, success, error);

        /**
         * Get information about whether the current wallet has been registered the producer.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return Information in JSON format. Such as:
         * { "Status": "Unregistered", "Info": null }
         *
         * {
         *    "Status": "Registered",
         *    "Info": {
         *      "OwnerPublicKey": "02775B47CCB0808BA70EA16800385DBA2737FDA090BB0EBAE948DD16FF658CA74D",
         *      "NodePublicKey": "02848A8F1880408C4186ED31768331BC9296E1B0C3EC7AE6F11E9069B16013A9C5",
         *      "NickName": "hello nickname",
         *      "URL": "www.google.com",
         *      "Location": 86,
         *      "Address": 127.0.0.1,
         *    }
         * }
         *
         * { "Status": "Canceled", "Info": { "Confirms": 2016 } }
         *
         * { "Status": "ReturnDeposit", "Info": null }
         */
        getRegisteredProducerInfo(args, success, error);

        //////////////////////////////////////////////////
        /*                      CRC                     */
        //////////////////////////////////////////////////

        /**
         * Generate cr info payload digest for signature.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param crPublicKey    The public key to identify a cr. Can't change later.
         * @param nickName       Nickname of cr.
         * @param url            URL of cr.
         * @param location       Location code.
         *
         * @return               The payload in JSON format contains the "Digest" field to be signed and then set the "Signature" field. Such as
         * {
         *     "Code":"210370a77a257aa81f46629865eb8f3ca9cb052fcfd874e8648cfbea1fbf071b0280ac",
         *     "DID":"b13bfbc6afd4e2d5227e659be5b808cbaa1c59d267",
         *     "Location":86,
         *     "NickName":"test",
         *     "Url":"test.com",
         *     "Digest":"9970b0612f9146f3f5744f7a843dfa6aac3534a6f44232e08469b212323be573",
         *     "Signature":""
         *     }
         */
        generateCRInfoPayload(args, success, error);

        /**
         * Generate unregister cr payload digest for signature.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param crDID          The id of cr will unregister
         * @return               The payload in JSON format contains the "Digest" field to be signed and then set the "Signature" field. Such as
         * {
         *     "DID":"4854185275217ffcf8c97177d4ef1599810c8b8f67",
         *     "Digest":"8e17a8bcacc5d70b5b312fccefc19d25d88ac6450322a846132e859509b88001",
         *     "Signature":""
         *     }
         */
        generateUnregisterCRPayload(args, success, error);

        /**
         * Create register cr transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param payloadJSON  Generate by GenerateCRInfoPayload().
         * @param amount       Amount must lager than 500,000,000,000 sela
         * @param memo         Remarks string. Can be empty string.
         * @return             The transaction in JSON format to be signed and published.
         */
        createRegisterCRTransaction(args, success, error);

        /**
         * Create update cr transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param payloadJSON  Generate by GenerateCRInfoPayload().
         * @param memo         Remarks string. Can be empty string.
         * @return             The transaction in JSON format to be signed and published.
         */
        createUpdateCRTransaction(args, success, error);

        /**
         * Create unregister cr transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param fromAddress  If this address is empty, SDK will pick available UTXO automatically.
         *                     Otherwise, pick UTXO from the specific address.
         * @param payloadJSON  Generate by GenerateUnregisterCRPayload().
         * @param memo         Remarks string. Can be empty string.
         * @return             The transaction in JSON format to be signed and published.
         */
        createUnregisterCRTransaction(args, success, error);

        /**
         * Create retrieve deposit cr transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param crPublicKey The public key to identify a cr.
         * @param amount      The available amount to be retrieved back.
         * @param memo        Remarks string. Can be empty string.
         * @return            The transaction in JSON format to be signed and published.
         */
        createRetrieveCRDepositTransaction(args, success, error);

        /**
         * Get information about whether the current wallet has been registered the producer.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return Information in JSON format. Such as:
         * { "Status": "Unregistered", "Info": null }
         *
         * {
         *    "Status": "Registered",
         *    "Info": {
         *      "CROwnerPublicKey": "02775B47CCB0808BA70EA16800385DBA2737FDA090BB0EBAE948DD16FF658CA74D",
         *      "CROwnerDID": "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP",
         *      "NickName": "hello nickname",
         *      "URL": "www.google.com",
         *      "Location": 86,
         *    }
         * }
         *
         * { "Status": "Canceled", "Info": { "Confirms": 2016 } }
         *
         * { "Status": "ReturnDeposit", "Info": null }
         */
        getRegisteredCRInfo(args, success, error);

        /**
         * Generate digest for signature of CR council members
         * @param payload
         * {
         *   "NodePublicKey": "...",
         *   "CRCouncilMemberDID": "...",
         * }
         * @return
         */
        CRCouncilMemberClaimNodeDigest(args, success, error);

        /**
         * @param payload
         * {
         *   "NodePublicKey": "...",
         *   "CRCouncilMemberDID": "...",
         *   "CRCouncilMemberSignature": "..."
         * }
         * @return
         */
        createCRCouncilMemberClaimNodeTransaction(args, success, error);

        //////////////////////////////////////////////////
        /*                    Proposal                  */
        //////////////////////////////////////////////////

        /**
         * Generate digest of payload.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Proposal payload. Must contain the following:
         * {
         *    "Type": 0,
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "031f7a5a6bf3b2450cd9da4048d00a8ef1cb4912b5057535f65f3cc0e0c36f13b4",
         *    "DraftHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *    "Budgets": [{"Type":0,"Stage":0,"Amount":"300"},{"Type":1,"Stage":1,"Amount":"33"},{"Type":2,"Stage":2,"Amount":"344"}],
         *    "Recipient": "EPbdmxUVBzfNrVdqJzZEySyWGYeuKAeKqv", // address
         * }
         *
         * Type can be value as below:
         * {
         *     Normal: 0x0000
         *     ELIP: 0x0100
         * }
         *
         * Budget must contain the following:
         * {
         *   "Type": 0,             // imprest = 0, normalPayment = 1, finalPayment = 2
         *   "Stage": 0,            // value can be [0, 128)
         *   "Amount": "100000000"  // sela
         * }
         *
         * @return Digest of payload.
         */
        proposalOwnerDigest(args, success, error);

        /**
         * Generate digest of payload.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Proposal payload. Must contain the following:
         * {
         *    "Type": 0,                   // same as mention on method ProposalOwnerDigest()
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "031f7a5a6bf3b2450cd9da4048d00a8ef1cb4912b5057535f65f3cc0e0c36f13b4", // Owner DID public key
         *    "DraftHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *    "Budgets": [                 // same as mention on method ProposalOwnerDigest()
         *      {"Type":0,"Stage":0,"Amount":"300"},{"Type":1,"Stage":1,"Amount":"33"},{"Type":2,"Stage":2,"Amount":"344"}
         *    ],
         *    "Recipient": "EPbdmxUVBzfNrVdqJzZEySyWGYeuKAeKqv", // address
         *
         *    // signature of owner
         *    "Signature": "ff0ff9f45478f8f9fcd50b15534c9a60810670c3fb400d831cd253370c42a0af79f7f4015ebfb4a3791f5e45aa1c952d40408239dead3d23a51314b339981b76",
         *    "CRCouncilMemberDID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY"
         * }
         *
         * @return Digest of payload.
         */
        proposalCRCouncilMemberDigest(args, success, error);

        /**
         * Calculate proposal hash.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Proposal payload signed by owner and CR committee. Same as payload of CreateProposalTransaction()
         * @return The transaction in JSON format to be signed and published.
         */
        calculateProposalHash(args, success, error);

        /**
         * Create CRC Proposal transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Signed payload.
         * {
         *   "ProposalHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *   "VoteResult": 1,    // approve = 0, reject = 1, abstain = 2
         *   "OpinionHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *   "DID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY", // did of CR council member's did
         *   // signature of CR council member
         *   "Signature": "ff0ff9f45478f8f9fcd50b15534c9a60810670c3fb400d831cd253370c42a0af79f7f4015ebfb4a3791f5e45aa1c952d40408239dead3d23a51314b339981b76"
         * }
         * @param memo             Remarks string. Can be empty string.
         * @return                 The transaction in JSON format to be signed and published.
         */
        createProposalTransaction(args, success, error);

        /**
         * Generate digest of payload.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Payload proposal review.
         * {
         *   "ProposalHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *   "VoteResult": 1,    // approve = 0, reject = 1, abstain = 2
         *   "OpinionHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *   "DID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY", // did of CR council member's did
         * }
         *
         * @return Digest of payload.
         */
        proposalReviewDigest(args, success, error);

        /**
         * Create proposal review transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Signed payload.
         * {
         *   "ProposalHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *   "VoteResult": 1,    // approve = 0, reject = 1, abstain = 2
         *   "OpinionHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *   "DID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY", // did of CR council member's did
         *   // signature of CR council member
         *   "Signature": "ff0ff9f45478f8f9fcd50b15534c9a60810670c3fb400d831cd253370c42a0af79f7f4015ebfb4a3791f5e45aa1c952d40408239dead3d23a51314b339981b76"
         * }
         *
         * @param memo Remarks string. Can be empty string.
         * @return The transaction in JSON format to be signed and published.
         */
        createProposalReviewTransaction(args, success, error);

        //////////////////////////////////////////////////
        /*               Proposal Tracking              */
        //////////////////////////////////////////////////

        /**
         * Generate digest of payload.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Proposal tracking payload.
         * {
         *   "ProposalHash": "7c5d2e7cfd7d4011414b5ddb3ab43e2aca247e342d064d1091644606748d7513",
         *   "MessageHash": "0b5ee188b455ab5605cd452d7dda5c205563e1b30c56e93c6b9fda133f8cc4d4",
         *   "Stage": 0, // value can be [0, 128)
         *   "OwnerPublicKey": "02c632e27b19260d80d58a857d2acd9eb603f698445cc07ba94d52296468706331",
         *   // If this proposal tracking is not use for changing owner, will be empty. Otherwise not empty.
         *   "NewOwnerPublicKey": "02c632e27b19260d80d58a857d2acd9eb603f698445cc07ba94d52296468706331",
         * }
         *
         * @return Digest of payload
         */
        proposalTrackingOwnerDigest(args, success, error);

        /**
         * Generate digest of payload.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Proposal tracking payload.
         * {
         *   "ProposalHash": "7c5d2e7cfd7d4011414b5ddb3ab43e2aca247e342d064d1091644606748d7513",
         *   "MessageHash": "0b5ee188b455ab5605cd452d7dda5c205563e1b30c56e93c6b9fda133f8cc4d4",
         *   "Stage": 0, // value can be [0, 128)
         *   "OwnerPublicKey": "02c632e27b19260d80d58a857d2acd9eb603f698445cc07ba94d52296468706331",
         *   // If this proposal tracking is not use for changing owner, will be empty. Otherwise not empty.
         *   "NewOwnerPublicKey": "02c632e27b19260d80d58a857d2acd9eb603f698445cc07ba94d52296468706331",
         *   "OwnerSignature": "9a24a084a6f599db9906594800b6cb077fa7995732c575d4d125c935446c93bbe594ee59e361f4d5c2142856c89c5d70c8811048bfb2f8620fbc18a06cb58109",
         * }
         *
         * @return Digest of payload.
         */
        proposalTrackingNewOwnerDigest(args, success, error);

        /**
         * Generate digest of payload.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Proposal tracking payload.
         * {
         *   "ProposalHash": "7c5d2e7cfd7d4011414b5ddb3ab43e2aca247e342d064d1091644606748d7513",
         *   "MessageHash": "0b5ee188b455ab5605cd452d7dda5c205563e1b30c56e93c6b9fda133f8cc4d4",
         *   "Stage": 0, // value can be [0, 128)
         *   "OwnerPublicKey": "02c632e27b19260d80d58a857d2acd9eb603f698445cc07ba94d52296468706331",
         *   // If this proposal tracking is not use for changing owner, will be empty. Otherwise not empty.
         *   "NewOwnerPublicKey": "02c632e27b19260d80d58a857d2acd9eb603f698445cc07ba94d52296468706331",
         *   "OwnerSignature": "9a24a084a6f599db9906594800b6cb077fa7995732c575d4d125c935446c93bbe594ee59e361f4d5c2142856c89c5d70c8811048bfb2f8620fbc18a06cb58109",
         *   // If NewOwnerPubKey is empty, this must be empty.
         *   "NewOwnerSignature": "9a24a084a6f599db9906594800b6cb077fa7995732c575d4d125c935446c93bbe594ee59e361f4d5c2142856c89c5d70c8811048bfb2f8620fbc18a06cb58109",
         *   "Type": 0, // common = 0, progress = 1, rejected = 2, terminated = 3, changeOwner = 4, finalized = 5
         *   "SecretaryGeneralOpinionHash": "7c5d2e7cfd7d4011414b5ddb3ab43e2aca247e342d064d1091644606748d7513",
         * }
         *
         * @return Digest of payload
         */
        proposalTrackingSecretaryDigest(args, success, error);

        /**
         * Create a proposal tracking transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param SecretaryGeneralSignedPayload Proposal tracking payload with JSON format by SecretaryGeneral signed
         * @param memo           Remarks string. Can be empty string.
         * @return               The transaction in JSON format to be signed and published.
         */
        createProposalTrackingTransaction(args, success, error);

        //////////////////////////////////////////////////
        /*      Proposal Secretary General Election     */
        //////////////////////////////////////////////////

        /**
         * @param payload Proposal secretary election payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "031f7a5a6bf3b2450cd9da4048d00a8ef1cb4912b5057535f65f3cc0e0c36f13b4",
         *    "DraftHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *    "SecretaryGeneralPublicKey": "...",
         *    "SecretaryGeneralDID": "...",
         * }
         * @return
         */
        proposalSecretaryGeneralElectionDigest(args, success, error);

        /**
         * @param payload Proposal secretary election payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "031f7a5a6bf3b2450cd9da4048d00a8ef1cb4912b5057535f65f3cc0e0c36f13b4",
         *    "DraftHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *    "SecretaryGeneralPublicKey": "...",
         *    "SecretaryGeneralDID": "...",
         *    "Signature": "...",
         *    "SecretaryGeneralSignature": "...",
         *    "CRCouncilMemberDID": "...",
         * }
         * @return
         */
        proposalSecretaryGeneralElectionCRCouncilMemberDigest(args, success, error);

        /**
         * @param payload Proposal secretary election payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "031f7a5a6bf3b2450cd9da4048d00a8ef1cb4912b5057535f65f3cc0e0c36f13b4",
         *    "DraftHash": "a3d0eaa466df74983b5d7c543de6904f4c9418ead5ffd6d25814234a96db37b0",
         *    "SecretaryGeneralPublicKey": "...",
         *    "SecretaryGeneralDID": "...",
         *    "Signature": "...",
         *    "SecretaryGeneralSignature": "...",
         *    "CRCouncilMemberDID": "...",
         *    "CRCouncilMemberSignature": "..."
         * }
         * @param memo Remarks string.
         * @return
         */
        createSecretaryGeneralElectionTransaction(args, success, error);

        //////////////////////////////////////////////////
        /*             Proposal Change Owner            */
        //////////////////////////////////////////////////

        /**
         * Use for owner & new owner sign
         * @param payload Proposal change owner payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "TargetProposalHash": "...",
         *    "NewRecipient": "...",
         *    "NewOwnerPublicKey": "...",
         * }
         * @return
         */
        proposalChangeOwnerDigest(args, success, error);

        /**
         * @param payload Proposal change owner payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "TargetProposalHash": "...",
         *    "NewRecipient": "...",
         *    "NewOwnerPublicKey": "...",
         *    "Signature": "...",
         *    "NewOwnerSignature": "...",
         *    "CRCouncilMemberDID": "..."
         * }
         * @return
         */
        proposalChangeOwnerCRCouncilMemberDigest(args, success, error);

        /**
         * @param payload Proposal change owner payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "TargetProposalHash": "...",
         *    "NewRecipient": "...",
         *    "NewOwnerPublicKey": "...",
         *    "Signature": "...",
         *    "NewOwnerSignature": "...",
         *    "CRCouncilMemberDID": "...",
         *    "CRCouncilMemberSignature": "...",
         * }
         * @param memo Remark string.
         * @return
         */
        createProposalChangeOwnerTransaction(args, success, error);

        //////////////////////////////////////////////////
        /*           Proposal Terminate Proposal        */
        //////////////////////////////////////////////////
        /**
         * @param payload Terminate proposal payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "TargetProposalHash": "...",
         * }
         * @return
         */
        terminateProposalOwnerDigest(args, success, error);

        /**
         * @param payload Terminate proposal payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "TargetProposalHash": "...",
         *    "Signature": "...",
         *    "CRCouncilMemberDID": "...",
         * }
         * @return
         */
        terminateProposalCRCouncilMemberDigest(args, success, error);

        /**
         * @param payload Terminate proposal payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "TargetProposalHash": "...",
         *    "Signature": "...",
         *    "CRCouncilMemberDID": "...",
         *    "CRCouncilMemberSignature": "...",
         * }
         * @param memo Remark string.
         * @return
         */
        createTerminateProposalTransaction(args, success, error);


        //////////////////////////////////////////////////
        /*               Proposal Withdraw              */
        //////////////////////////////////////////////////

        /**
         * Generate digest of payload.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Proposal payload.
         * {
         *   "ProposalHash": "7c5d2e7cfd7d4011414b5ddb3ab43e2aca247e342d064d1091644606748d7513",
         *   "OwnerPublicKey": "02c632e27b19260d80d58a857d2acd9eb603f698445cc07ba94d52296468706331",
         *   "Recipient": "EPbdmxUVBzfNrVdqJzZEySyWGYeuKAeKqv", // address
	     *   "Amount": "100000000", // 1 ela = 100000000 sela
         * }
         *
         * @return Digest of payload.
         */
        proposalWithdrawDigest(args, success, error);

        /**
         * Create proposal withdraw transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param payload Proposal payload.
         * {
         *   "ProposalHash": "7c5d2e7cfd7d4011414b5ddb3ab43e2aca247e342d064d1091644606748d7513",
         *   "OwnerPublicKey": "02c632e27b19260d80d58a857d2acd9eb603f698445cc07ba94d52296468706331",
         *   "Recipient": "EPbdmxUVBzfNrVdqJzZEySyWGYeuKAeKqv", // address
         *   "Amount": "100000000", // 1 ela = 100000000 sela
         *   "Signature": "9a24a084a6f599db9906594800b6cb077fa7995732c575d4d125c935446c93bbe594ee59e361f4d5c2142856c89c5d70c8811048bfb2f8620fbc18a06cb58109"
         * }
         *
         * @param memo Remarks string. Can be empty string.
         *
         * @return Transaction in JSON format.
         */
        createProposalWithdrawTransaction(args, success, error);

        /**
         * Get the erc20 token list
         * @param address ethsc address.
         *
         * @return
         */
        getERC20TokenList(address: string) : Promise<ERC20TokenInfo[]>;

        //////////////////////////////////////////////////
        /*               Backup and restore             */
        //////////////////////////////////////////////////

        /**
         * Returns the list of files (info only) to backup for the wallet, and for each of them,
         * its current size and last modified date.
         *
         * Backup files contain only information about the SPV synchronization state. They do not contain any
         * private information.
         */
        getBackupInfo(masterWalletID: string): Promise<BackupInfo>;

        /**
         * Returns a Reader instance that can be used to read the target backup file content in order to save
         * it somewhere else.
         */
        getBackupFile(masterWalletID: string, fileName: string): Promise<BackupFileReader>;

        /**
         * Returns a Writer instance that can be used to overwrite one of the SPV synchronization files in order
         * to restore a more recent state of the wallet.
         */
        restoreBackupFile(masterWalletID: string, fileName: string): Promise<BackupFileWriter>;
    }

    /**
     * Information about ERC20 Token
     */
    type ERC20TokenInfo = {
        type: string;
        symbol: string;
        name: string;
        decimals: string;
        contractAddress: string;
        balance: string;
    }

    /**
     * Reader allowing to read backup files content in chunks.
     */
    class BackupFileReader {
        read(bytesCount: number): Promise<Uint8Array>;
        close();
    }

    /**
     * Writer allowing to write backup files content in chunks.
     */
    class BackupFileWriter {
        write(bytes: Uint8Array): Promise<void>;
        close();
    }

    /**
     * Information about
     */
    type BackupFile = {
        fileName: string; // File name in device storage
        fileSize: number; // Size in bytes
        lastModified: Date;
    }

    class BackupInfo {
        ELADatabase: BackupFile; // .db file for the ELA subwallet sync state
        IDChainDatabase: BackupFile; // .db file for the ID sidechain subwallet sync state
        ETHChainDatabase: BackupFile; // .db file for the ETH sidechain subwallet sync state
    }
}