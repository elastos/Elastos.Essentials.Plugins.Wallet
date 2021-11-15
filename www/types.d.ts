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
         * Destroy the MasterWalletManager.
         */
        destroy(args, success, error);

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
         * Create master wallet with single private key (for eth side-chain single private key), or return existing master wallet if current master wallet manager has the master wallet id.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param singlePrivateKey uint256 hex string of private key
         * @param password use to encrypt important things(such as private key) in memory. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @return If success will return a pointer of master wallet interface.
         */
        createMasterWalletWithPrivKey(args, success, error);

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
         * Export private of the current wallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param payPassword use to decrypt and generate private temporarily. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @return If success will return the private of master wallet.
         */
         exportWalletWithPrivateKey(args, success, error);

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
         * For Elastos-based or btc wallet: Derivate @count addresses from @index.  Note that if create the
         * sub-wallet by setting the singleAddress to true, will always set @index to 0, set @count to 1,
         * set @internal to false.
         * For ETH-based sidechain: Only return a single address. Ignore all parameters.
         *
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @index start from 0.
         * @count count of addresses we need.
         * @internal change address for true or normal receive address for false.
         * @return a new address or addresses as required.
         */
        getAddresses(args, success, error);

        /**
         * For Elastos-based or btc wallet: Get @count public keys from @index.  Note that if create the
         * sub-wallet by setting the singleAddress to true, will always set @index to 0, set @count to 1,
         * set @internal to false.
         * For ETH-based sidechain: Only return a single public key. Ignore all parameters.
         *
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param start to specify start index of all public key list.
         * @param count specifies the count of public keys we need.
         * @return public keys in json format.
         */
        getPublicKeys(args, success, error);

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
         * Sign a transaction or append sign to a multi-sign transaction and return the content of transaction in json format.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param tx transaction created by Create*Transaction().
         * @param payPassword use to decrypt the root private key temporarily. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @return If success return the content of transaction in json format.
         */
        signTransaction(args, success, error);


        /**
         * Sign message with private key of address.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param address will sign the digest with private key of this address.
         * @param digest hex string of sha256
         * @param payPassword pay password.
         * @return If success, signature will be returned.
         */
         signDigest(args, success, error);

        /**
         * Verify signature with specify public key.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param pubkey public key hex string.
         * @param digest hex string of sha256.
         * @param payPassword pay password.
         * @return If success, signature will be returned.
         */
         verifyDigest(args, success, error);

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
         * Convert tx to raw transaction.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param tx transaction json
         * @return  tx in hex string format.
         */
         convertToRawTransaction(args, success, error);


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
         * @param index specify start index of all DID list.
         * @param count specify count of DID we need.
         * @param internal change address for true or normal external address for false.
         * @return If success return all DID in JSON format.
         *
         * example:
         * GetDID(0, 3) will return below
         * {
         *     "DID": ["iZDgaZZjRPGCE4x8id6YYJ158RxfTjTnCt", "iPbdmxUVBzfNrVdqJzZEySyWGYeuKAeKqv", "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP"],
         * }
         */
        getDID(args, success, error);

        /**
         * Get all CID derived of current subwallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param index specify start index of all CID list.
         * @param count specify count of CID we need.
         * @param internal change address for true or normal external address for false.
         * @return If success return CID in JSON format.
         *
         * example:
         * GetCID(0, 3) will return below
         * {
         *     "CID": ["iZDgaZZjRPGCE4x8id6YYJ158RxfTjTnCt", "iPbdmxUVBzfNrVdqJzZEySyWGYeuKAeKqv", "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP"],
         * }
         */
        getCID(args, success, error);

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
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param targetAddress
         * @param amount
         * @param amountUnit
         * @param gasPrice
         * @param gasPriceUnit
         * @param gasLimit
         * @param nonce
         * @return
         */
        createTransfer(args, success, error);

        /**
         *
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @param targetAddress
         * @param amount
         * @param amountUnit
         * @param gasPrice
         * @param gasPriceUnit
         * @param gasLimit
         * @param data
         * @param nonce
         * @return
         */
        createTransferGeneric(args, success, error);

        /**
         * Export private of the current wallet.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param payPassword use to decrypt and generate private temporarily. Pay password should between 8 and 128, otherwise will throw invalid argument exception.
         * @return If success will return the private of master wallet.
         */
         exportETHSCPrivateKey(args, success, error);

        //MainchainSubWallet

        /**
         * Deposit token from the main chain to side chains, such as ID chain or token chain, etc.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @version 0x00 means old deposit tx, 0x01 means new deposit tx, other value will throw exception.
		 * @param inputs UTXO which will be used. eg
		 * [
		 *   {
		 *     "TxHash": "...", // string
		 *     "Index": 123, // int
		 *     "Address": "...", // string
		 *     "Amount": "100000000" // bigint string in SELA
		 *   },
		 *   ...
		 * ]
		 * NOTE:  (utxo input amount) >= amount + 10000 sela + fee
		 * @param sideChainID Chain id of the side chain
		 * @param amount The amount that will be deposit to the side chain.
		 * @param sideChainAddress Receive address of side chain
		 * @param lockAddress Generate from genesis block hash
		 * @param fee Fee amount. Bigint string in SELA
		 * @param memo Remarks string. Can be empty string
		 * @return The transaction in JSON format to be signed and published
		 */
        createDepositTransaction(args, success, error);

        //////////////////////////////////////////////////
        /*                      Vote                    */
        //////////////////////////////////////////////////

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
        createVoteTransaction(args, success, error);

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
         * Get address of owner public key.
         * @param masterWalletID is the unique identification of a master wallet object.
         * @param chainID unique identity of a sub wallet. Chain id should not be empty.
         * @return Address of owner public key.
         */
        getOwnerAddress(args, success, error);

        /**
        * Get deposit address of owner.
        * @param masterWalletID is the unique identification of a master wallet object.
        * @param chainID unique identity of a sub wallet. Chain id should not be empty.
        * @return Deposit address of owner.
        */
        getOwnerDepositAddress(args, success, error);


        //////////////////////////////////////////////////
        /*                      CRC                     */
        //////////////////////////////////////////////////

        /**
        * Get CR deposit address.
        * @param masterWalletID is the unique identification of a master wallet object.
        * @param chainID unique identity of a sub wallet. Chain id should not be empty.
        * @return Deposit address of CR.
        */
        getCRDepositAddress(args, success, error);

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
        /*              Reserve Custom ID               */
        //////////////////////////////////////////////////

        /**
         * @param payload Reserve Custom ID payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "ReservedCustomIDList": ["...", "...", ...],
         * }
         * @return
         */
        reserveCustomIDOwnerDigest(args, success, error);

         /**
         * @param payload Reserve Custom ID payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "ReservedCustomIDList": ["...", "...", ...],
         *    "Signature": "...",
         *    "CRCouncilMemberDID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
         * }
         * @return
         */
        reserveCustomIDCRCouncilMemberDigest(args, success, error);

        /**
         * @param inputs UTXO which will be used. eg
         * [
         *   {
         *     "TxHash": "...", // string
         *     "Index": 123, // int
         *     "Address": "...", // string
         *     "Amount": "100000000" // bigint string in SELA
         *   },
         *   ...
         * ]
         * @param payload Reserve Custom ID payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "ReservedCustomIDList": ["...", "...", ...],
         *    "Signature": "...",
         *    "CRCouncilMemberDID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
         *    "CRCouncilMemberSignature": "...",
         * }
         * @param fee Fee amount. Bigint string in SELA
         * @param memo Remark string
         * @return
         */
         createReserveCustomIDTransaction(args, success, error);


        //////////////////////////////////////////////////
        /*               Receive Custom ID              */
        //////////////////////////////////////////////////

        /**
         * @param payload Receive Custom ID payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "ReceivedCustomIDList": ["...", "...", ...],
         *    "ReceiverDID": "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP"
         * }
         * @return
         */
        receiveCustomIDOwnerDigest(args, success, error);

        /**
         * @param payload Receive Custom ID payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "ReceivedCustomIDList": ["...", "...", ...],
         *    "ReceiverDID": "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP"
         *    "Signature": "...",
         *    "CRCouncilMemberDID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
         * }
         * @return
         */
        receiveCustomIDCRCouncilMemberDigest(args, success, error);

        /**
         * @param inputs UTXO which will be used. eg
         * [
         *   {
         *     "TxHash": "...", // string
         *     "Index": 123, // int
         *     "Address": "...", // string
         *     "Amount": "100000000" // bigint string in SELA
         *   },
         *   ...
         * ]
         * @param payload Receive Custom ID payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "ReceivedCustomIDList": ["...", "...", ...],
         *    "ReceiverDID": "iT42VNGXNUeqJ5yP4iGrqja6qhSEdSQmeP"
         *    "Signature": "...",
         *    "CRCouncilMemberDID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
         *    "CRCouncilMemberSignature": "...",
         * }
         * @param fee Fee amount. Bigint string in SELA
         * @param memo Remark string
         * @return
         */
        createReceiveCustomIDTransaction(args, success, error);

        //////////////////////////////////////////////////
        /*              Change Custom ID Fee            */
        //////////////////////////////////////////////////

        /**
         * @param payload Change custom ID fee payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "CustomIDFeeRateInfo": {
         *      "RateOfCustomIDFee": 10000,
         *      "EIDEffectiveHeight": 10000
         *    }
         * }
         * @return
         */
        changeCustomIDFeeOwnerDigest(args, success, error);

        /**
         * @param payload Change custom ID fee payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "CustomIDFeeRateInfo": {
         *      "RateOfCustomIDFee": 10000,
         *      "EIDEffectiveHeight": 10000
         *    },
         *    "Signature": "...",
         *    "CRCouncilMemberDID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
         * }
         * @return
         */
        changeCustomIDFeeCRCouncilMemberDigest(args, success, error);

        /**
         * @param inputs UTXO which will be used. eg
         * [
         *   {
         *     "TxHash": "...", // string
         *     "Index": 123, // int
         *     "Address": "...", // string
         *     "Amount": "100000000" // bigint string in SELA
         *   },
         *   ...
         * ]
         * @param payload Change custom ID fee payload
         * {
         *    "CategoryData": "testdata",  // limit: 4096 bytes
         *    "OwnerPublicKey": "...",
         *    "DraftHash": "...",
         *    "DraftData": "", // Optional, string format, limit 1 Mbytes
         *    "CustomIDFeeRateInfo": {
         *      "RateOfCustomIDFee": 10000,
         *      "EIDEffectiveHeight": 10000
         *    },
         *    "Signature": "...",
         *    "CRCouncilMemberDID": "icwTktC5M6fzySQ5yU7bKAZ6ipP623apFY",
         *    "CRCouncilMemberSignature": "...",
         * }
         * @param fee Fee amount. Bigint string in SELA
         * @param memo Remark string
         * @return
         */
        createChangeCustomIDFeeTransaction(args, success, error);

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

        // BTCSubwallet

        /**
         * get legay addresses of btc
         * @param masterWalletID is the unique identification of a master wallet object.
         * @index start from where.
         * @count how many address we need.
         * @internal change address for true or normal receive address for false.
         * @return as required
         */
        getLegacyAddresses(args, success, error);

        /**
         * create btc transaction
         * @param masterWalletID is the unique identification of a master wallet object.
         * @inputs in json array format. eg:
         * [
         * {
         *   "TxHash": "...", // uint256 string
         *   "Index": 0, // uint16_t
         *   "Address": "...", // btc address
         *   "Amount": "100000000" // bigint string in satoshi
         * },
         * {
         *   ...
         * }
         * ]
         * @outputs in json array format. eg:
         * [
         * {
         *   "Address": "...", // btc address
         *   "Amount": "100000000" // bigint string in satoshi
         * },
         * {
         *   ...
         * }
         * ]
         * @changeAddress change address in string format.
         * @feePerKB how much fee (satoshi) per kb of tx size.
         * @return unsigned serialized transaction in json format.
         */
        createBTCTransaction(args, success, error);
    }
}