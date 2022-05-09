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

package org.elastos.essentials.plugins.wallet;

import java.io.File;
import java.util.ArrayList;
import java.util.concurrent.Semaphore;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.elastos.spvcore.BTCSubWallet;
import org.elastos.spvcore.ElastosBaseSubWallet;
import org.elastos.spvcore.EthSidechainSubWallet;
import org.elastos.spvcore.IDChainSubWallet;
import org.elastos.spvcore.MainchainSubWallet;
import org.elastos.spvcore.MasterWallet;
import org.elastos.spvcore.MasterWalletManager;
import org.elastos.spvcore.SidechainSubWallet;
import org.elastos.spvcore.SubWallet;
import org.elastos.spvcore.WalletException;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;

/**
 * wallet webview jni
 */
public class Wallet extends CordovaPlugin {

    private static final String TAG = "Wallet";

    private static Semaphore walletSemaphore;

    private static int walletRefCount = 0;
    // only wallet dapp can use this plugin
    private static MasterWalletManager mMasterWalletManager = null;
    private String keySuccess = "success";
    private String keyError = "error";
    private String keyCode = "code";
    private String keyMessage = "message";
    private String keyException = "exception";

    public static final String IDChain = "IDChain";

    private static String s_dataRootPath = "";
    private static String s_netType = "MainNet";
    private static String s_netConfig = "";
    private static String s_logLevel = "warning";

    private int errCodeParseJsonInAction = 10000;
    private int errCodeInvalidArg = 10001;
    private int errCodeInvalidMasterWallet = 10002;
    private int errCodeInvalidSubWallet = 10003;
    private int errCodeCreateMasterWallet = 10004;
    private int errCodeCreateSubWallet = 10005;
    private int errCodeInvalidMasterWalletManager = 10007;
    private int errCodeImportFromKeyStore = 10008;
    private int errCodeImportFromMnemonic = 10009;
    private int errCodeSubWalletInstance = 10010;
    private int errCodeInvalidDIDManager = 10011;
    private int errCodeInvalidDID = 10012;
    private int errCodeActionNotFound = 10013;

    private int errCodeWalletException = 20000;

    /**
     * Called when the system is about to start resuming a previous activity.
     *
     * @param multitasking Flag indicating if multitasking is turned on for app
     */
    @Override
    public void onPause(boolean multitasking) {
        super.onPause(multitasking);
    }

    /**
     * Called when the activity will start interacting with the user.
     *
     * @param multitasking Flag indicating if multitasking is turned on for app
     */
    @Override
    public void onResume(boolean multitasking) {
        super.onResume(multitasking);
    }

    /**
     * Called when the activity is becoming visible to the user.
     */
    @Override
    public void onStart() {
        super.onStart();
    }

    /**
     * Called when the activity is no longer visible to the user.
     */
    @Override
    public void onStop() {
        super.onStop();
    }

    /**
     * The final call you receive before your activity is destroyed.
     */
    @Override
    public void onDestroy() {
        Log.i(TAG, "onDestroy");
        walletRefCount--;

        if (mMasterWalletManager != null) {
            if (walletRefCount == 0) {
                destroyMasterWalletManager();
            }
        }

        super.onDestroy();
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        walletRefCount++;
    }

    private void destroyMasterWalletManager() {
        Log.i(TAG, "destroyMasterWalletManager");
        if (mMasterWalletManager != null) {
            try {
                walletSemaphore.acquire();

                mMasterWalletManager.Dispose();
                mMasterWalletManager = null;
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            walletSemaphore.release();
        }
    }

    private String formatWalletName(String masterWalletID) {
        return masterWalletID;
    }

    private String formatWalletName(String masterWalletID, String chainID) {
        return masterWalletID + ":" + chainID;
    }

    private boolean parametersCheck(JSONArray args) throws JSONException {
        for (int i = 0; i < args.length(); i++) {
            if (args.isNull(i)) {
                Log.e(TAG, "arg[" + i + "] = " + args.get(i) + " should not be null");
                return false;
            }
        }

        return true;
    }

    private void exceptionProcess(Exception e, CallbackContext cc, String msg) {
        e.printStackTrace();
        cc.error(e.toString());
    }

    private void exceptionProcess(WalletException e, CallbackContext cc, String msg) throws JSONException {
        e.printStackTrace();

        try {
            JSONObject exceptionJson = new JSONObject(e.GetErrorInfo());
            long exceptionCode = exceptionJson.getLong("Code");
            String exceptionMsg = exceptionJson.getString("Message");

            JSONObject errJson = new JSONObject();
            errJson.put(keyCode, exceptionCode);
            errJson.put(keyMessage, msg + ": " + exceptionMsg);
            if (exceptionJson.has("Data")) {
                errJson.put("Data", exceptionJson.getInt("Data"));
            }

            Log.e(TAG, errJson.toString());
            cc.error(errJson);
        } catch (JSONException je) {
            JSONObject errJson = new JSONObject();

            errJson.put(keyCode, errCodeWalletException);
            errJson.put(keyMessage, msg);
            errJson.put(keyException, e.GetErrorInfo());

            Log.e(TAG, errJson.toString());

            cc.error(errJson);
        }
    }

    private void errorProcess(CallbackContext cc, int code, Object msg) {
        try {
            JSONObject errJson = new JSONObject();

            errJson.put(keyCode, code);
            errJson.put(keyMessage, msg);
            Log.e(TAG, errJson.toString());

            cc.error(errJson);
        } catch (JSONException e) {
            String m = "Make json error message exception: " + e.toString();
            Log.e(TAG, m);
            cc.error(m);
        }
    }

    private MasterWallet getIMasterWallet(String masterWalletID) {
        if (mMasterWalletManager == null) {
            Log.e(TAG, "Master wallet manager has not initialize");
            return null;
        }

        return mMasterWalletManager.GetMasterWallet(masterWalletID);
    }

    private SubWallet getSubWallet(String masterWalletID, String chainID) {
        MasterWallet masterWallet = getIMasterWallet(masterWalletID);
        if (masterWallet == null) {
            Log.e(TAG, formatWalletName(masterWalletID) + " not found");
            return null;
        }

        ArrayList<SubWallet> subWalletList = masterWallet.GetAllSubWallets();
        for (int i = 0; i < subWalletList.size(); i++) {
            if (chainID.equals(subWalletList.get(i).GetChainID())) {
                return subWalletList.get(i);
            }
        }

        Log.e(TAG, formatWalletName(masterWalletID, chainID) + " not found");
        return null;
    }

    private EthSidechainSubWallet getEthSidechainSubWallet(String masterWalletID, String chainID) {
        SubWallet subWallet = getSubWallet(masterWalletID, chainID);

        if ((subWallet instanceof EthSidechainSubWallet)) {
            return (EthSidechainSubWallet) subWallet;
        }
        return null;
    }

    private BTCSubWallet getBTCSubWallet(String masterWalletID) {
        SubWallet subWallet = getSubWallet(masterWalletID, "BTC");

        if ((subWallet instanceof BTCSubWallet)) {
            return (BTCSubWallet) subWallet;
        }
        return null;
    }

    private String[] JSONArray2Array(JSONArray jsonArray) throws JSONException {
        String[] strArray = new String[jsonArray.length()];
        for (int i=0; i<jsonArray.length(); i++) {
            strArray[i] = jsonArray.getString(i);
        }
        return strArray;
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext cc) {
        Log.i(TAG, "action => '" + action + "'");
        try {
            if (false == parametersCheck(args)) {
                errorProcess(cc, errCodeInvalidArg, "Parameters contain 'null' value in action '" + action + "'");
                return false;
            }
            switch (action) {
                // Master wallet manager
                case "init":
                    this.init(args, cc);
                    break;
                case "destroy":
                    this.destroy(args, cc);
                    break;
                case "getVersion":
                    this.getVersion(args, cc);
                    break;
                case "setLogLevel":
                    this.setLogLevel(args, cc);
                    break;
                case "setNetwork":
                    this.setNetwork(args, cc);
                    break;
                case "generateMnemonic":
                    this.generateMnemonic(args, cc);
                    break;
                case "createMasterWallet":
                    this.createMasterWallet(args, cc);
                    break;
                case "createMasterWalletWithPrivKey":
                    this.createMasterWalletWithPrivKey(args, cc);
                    break;
                case "createMultiSignMasterWallet":
                    this.createMultiSignMasterWallet(args, cc);
                    break;
                case "createMultiSignMasterWalletWithPrivKey":
                    this.createMultiSignMasterWalletWithPrivKey(args, cc);
                    break;
                case "createMultiSignMasterWalletWithMnemonic":
                    this.createMultiSignMasterWalletWithMnemonic(args, cc);
                    break;
                case "getAllMasterWallets":
                    this.getAllMasterWallets(args, cc);
                    break;
                case "getMasterWallet":
                    this.getMasterWallet(args, cc);
                    break;
                case "importWalletWithKeystore":
                    this.importWalletWithKeystore(args, cc);
                    break;
                case "importWalletWithMnemonic":
                    this.importWalletWithMnemonic(args, cc);
                    break;
                case "importWalletWithSeed":
                    this.importWalletWithSeed(args, cc);
                    break;
                case "exportWalletWithKeystore":
                    this.exportWalletWithKeystore(args, cc);
                    break;
                case "exportWalletWithMnemonic":
                    this.exportWalletWithMnemonic(args, cc);
                    break;
                case "exportWalletWithSeed":
                    this.exportWalletWithSeed(args, cc);
                    break;
                case "exportWalletWithPrivateKey":
                    this.exportWalletWithPrivateKey(args, cc);
                    break;

                // Master wallet
                case "getMasterWalletBasicInfo":
                    this.getMasterWalletBasicInfo(args, cc);
                    break;
                case "getAllSubWallets":
                    this.getAllSubWallets(args, cc);
                    break;
                case "createSubWallet":
                    this.createSubWallet(args, cc);
                    break;
                case "destroyWallet":
                    this.destroyWallet(args, cc);
                    break;
                case "destroySubWallet":
                    this.destroySubWallet(args, cc);
                    break;
                case "verifyPassPhrase":
                    this.verifyPassPhrase(args, cc);
                    break;
                case "verifyPayPassword":
                    this.verifyPayPassword(args, cc);
                    break;
                case "getPubKeyInfo":
                    this.getPubKeyInfo(args, cc);
                    break;
                case "isAddressValid":
                    this.isAddressValid(args, cc);
                    break;
                case "isSubWalletAddressValid":
                    this.isSubWalletAddressValid(args, cc);
                    break;
                case "getSupportedChains":
                    this.getSupportedChains(args, cc);
                    break;
                case "changePassword":
                    this.changePassword(args, cc);
                    break;
                case "resetPassword":
                    this.resetPassword(args, cc);
                    break;

                // SubWallet
                case "getAddresses":
                    this.getAddresses(args, cc);
                    break;
                case "getPublicKeys":
                    this.getPublicKeys(args, cc);
                    break;
                case "createTransaction":
                    this.createTransaction(args, cc);
                    break;
                case "signTransaction":
                    this.signTransaction(args, cc);
                    break;
                case "signDigest":
                    this.signDigest(args, cc);
                    break;
                case "verifyDigest":
                    this.verifyDigest(args, cc);
                    break;
                case "getTransactionSignedInfo":
                    this.getTransactionSignedInfo(args, cc);
                    break;
                case "convertToRawTransaction":
                    this.convertToRawTransaction(args, cc);
                    break;

                // ID chain subwallet
                case "createIdTransaction":
                    this.createIdTransaction(args, cc);
                    break;
                case "getDID":
                    this.getDID(args, cc);
                    break;
                case "getCID":
                    this.getCID(args, cc);
                    break;
                case "didSign":
                    this.didSign(args, cc);
                    break;
                case "verifySignature":
                    this.verifySignature(args, cc);
                    break;
                case "getPublicKeyDID":
                    this.getPublicKeyDID(args, cc);
                    break;
                case "getPublicKeyCID":
                    this.getPublicKeyCID(args, cc);
                    break;

                //ETHSideChainSubWallet
                case "createTransfer":
                    this.createTransfer(args, cc);
                    break;
                case "createTransferGeneric":
                    this.createTransferGeneric(args, cc);
                    break;
                case "exportETHSCPrivateKey":
                    this.exportETHSCPrivateKey(args, cc);
                    break;

                // Main chain subwallet
                case "createDepositTransaction":
                    this.createDepositTransaction(args, cc);
                    break;
                // -- vote
                case "createVoteTransaction":
                    this.createVoteTransaction(args, cc);
                    break;

                // -- producer
                case "generateProducerPayload":
                    this.generateProducerPayload(args, cc);
                    break;
                case "generateCancelProducerPayload":
                    this.generateCancelProducerPayload(args, cc);
                    break;
                case "createRegisterProducerTransaction":
                    this.createRegisterProducerTransaction(args, cc);
                    break;
                case "createUpdateProducerTransaction":
                    this.createUpdateProducerTransaction(args, cc);
                    break;
                case "createCancelProducerTransaction":
                    this.createCancelProducerTransaction(args, cc);
                    break;
                case "createRetrieveDepositTransaction":
                    this.createRetrieveDepositTransaction(args, cc);
                    break;
                case "getOwnerPublicKey":
                    this.getOwnerPublicKey(args, cc);
                    break;
                case "getOwnerAddress":
                    this.getOwnerAddress(args, cc);
                    break;
                case "getOwnerDepositAddress":
                    this.getOwnerDepositAddress(args, cc);
                    break;
                // -- CRC
                case "getCRDepositAddress":
                    this.getCRDepositAddress(args, cc);
                    break;
                case "generateCRInfoPayload":
                    this.generateCRInfoPayload(args, cc);
                    break;
                case "generateUnregisterCRPayload":
                    this.generateUnregisterCRPayload(args, cc);
                    break;
                case "createRegisterCRTransaction":
                    this.createRegisterCRTransaction(args, cc);
                    break;
                case "createUpdateCRTransaction":
                    this.createUpdateCRTransaction(args, cc);
                    break;
                case "createUnregisterCRTransaction":
                    this.createUnregisterCRTransaction(args, cc);
                    break;
                case "createRetrieveCRDepositTransaction":
                    this.createRetrieveCRDepositTransaction(args, cc);
                    break;
                case "CRCouncilMemberClaimNodeDigest":
                    this.CRCouncilMemberClaimNodeDigest(args, cc);
                    break;
                case "createCRCouncilMemberClaimNodeTransaction":
                    this.createCRCouncilMemberClaimNodeTransaction(args, cc);
                    break;
                // -- Proposal
                case "proposalOwnerDigest":
                    this.proposalOwnerDigest(args, cc);
                    break;
                case "proposalCRCouncilMemberDigest":
                    this.proposalCRCouncilMemberDigest(args, cc);
                    break;
                case "calculateProposalHash":
                    this.calculateProposalHash(args, cc);
                    break;
                case "createProposalTransaction":
                    this.createProposalTransaction(args, cc);
                    break;
                case "proposalReviewDigest":
                    this.proposalReviewDigest(args, cc);
                    break;
                case "createProposalReviewTransaction":
                    this.createProposalReviewTransaction(args, cc);
                    break;
                // -- Proposal Tracking
                case "proposalTrackingOwnerDigest":
                    this.proposalTrackingOwnerDigest(args, cc);
                    break;
                case "proposalTrackingNewOwnerDigest":
                    this.proposalTrackingNewOwnerDigest(args, cc);
                    break;
                case "proposalTrackingSecretaryDigest":
                    this.proposalTrackingSecretaryDigest(args, cc);
                    break;
                case "createProposalTrackingTransaction":
                    this.createProposalTrackingTransaction(args, cc);
                    break;

                // -- Proposal Secretary General Election
                case "proposalSecretaryGeneralElectionDigest":
                    this.proposalSecretaryGeneralElectionDigest(args, cc);
                    break;
                case "proposalSecretaryGeneralElectionCRCouncilMemberDigest":
                    this.proposalSecretaryGeneralElectionCRCouncilMemberDigest(args, cc);
                    break;
                case "createSecretaryGeneralElectionTransaction":
                    this.createSecretaryGeneralElectionTransaction(args, cc);
                    break;

                // -- Proposal Change Owner
                case "proposalChangeOwnerDigest":
                    this.proposalChangeOwnerDigest(args, cc);
                    break;
                case "proposalChangeOwnerCRCouncilMemberDigest":
                    this.proposalChangeOwnerCRCouncilMemberDigest(args, cc);
                    break;
                case "createProposalChangeOwnerTransaction":
                    this.createProposalChangeOwnerTransaction(args, cc);
                    break;

                // -- Proposal Terminate Proposal
                case "terminateProposalOwnerDigest":
                    this.terminateProposalOwnerDigest(args, cc);
                    break;
                case "terminateProposalCRCouncilMemberDigest":
                    this.terminateProposalCRCouncilMemberDigest(args, cc);
                    break;
                case "createTerminateProposalTransaction":
                    this.createTerminateProposalTransaction(args, cc);
                    break;

                // -- Reserve Custom ID
                case "reserveCustomIDOwnerDigest":
                    this.reserveCustomIDOwnerDigest(args, cc);
                    break;
                case "reserveCustomIDCRCouncilMemberDigest":
                    this.reserveCustomIDCRCouncilMemberDigest(args, cc);
                    break;
                case "createReserveCustomIDTransaction":
                    this.createReserveCustomIDTransaction(args, cc);
                    break;

                // -- Receive Custom ID
                case "receiveCustomIDOwnerDigest":
                    this.receiveCustomIDOwnerDigest(args, cc);
                    break;
                case "receiveCustomIDCRCouncilMemberDigest":
                    this.receiveCustomIDCRCouncilMemberDigest(args, cc);
                    break;
                case "createReceiveCustomIDTransaction":
                    this.createReceiveCustomIDTransaction(args, cc);
                    break;

                // -- Change Custom ID Fee
                case "changeCustomIDFeeOwnerDigest":
                    this.changeCustomIDFeeOwnerDigest(args, cc);
                    break;
                case "changeCustomIDFeeCRCouncilMemberDigest":
                    this.changeCustomIDFeeCRCouncilMemberDigest(args, cc);
                    break;
                case "createChangeCustomIDFeeTransaction":
                    this.createChangeCustomIDFeeTransaction(args, cc);
                    break;

                // -- Proposal Withdraw
                case "proposalWithdrawDigest":
                    this.proposalWithdrawDigest(args, cc);
                    break;
                case "createProposalWithdrawTransaction":
                    this.createProposalWithdrawTransaction(args, cc);
                    break;

                // -- Proposal Register side-chain
                case "registerSidechainOwnerDigest":
                    this.registerSidechainOwnerDigest(args, cc);
                    break;
                case "registerSidechainCRCouncilMemberDigest":
                    this.registerSidechainCRCouncilMemberDigest(args, cc);
                    break;
                case "createRegisterSidechainTransaction":
                    this.createRegisterSidechainTransaction(args, cc);
                    break;

                // Side chain subwallet
                case "createWithdrawTransaction":
                    this.createWithdrawTransaction(args, cc);
                    break;

                case "getLegacyAddresses":
                    this.getLegacyAddresses(args, cc);
                    break;
                case "createBTCTransaction":
                    this.createBTCTransaction(args, cc);
                    break;
                default:
                    errorProcess(cc, errCodeActionNotFound, "Action '" + action + "' not found, please check!");
                    return false;
            }
        } catch (JSONException e) {
            e.printStackTrace();
            errorProcess(cc, errCodeParseJsonInAction, "Execute action '" + action + "' exception: " + e.toString());
            return false;
        }

        return true;
    }

    public void init(JSONArray args, CallbackContext cc) throws JSONException {
        if (mMasterWalletManager != null) {
            cc.success("");
            return;
        }

        int idx = 0;
        String dir = args.getString(idx++);
        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        if ((dir == null) || dir.isEmpty()) {
            errorProcess(cc, errCodeInvalidDID, "Invalid dir");
        }

        String rootPath = dir;
        if (!dir.startsWith("/")) {
            rootPath = cordova.getActivity().getFilesDir() + "/" + dir;
        }
        rootPath = rootPath + "/spv";

        s_dataRootPath = rootPath + "/data/";
        File destDir = new File(s_dataRootPath);
        if (!destDir.exists()) {
            destDir.mkdirs();
        }

        try {
            Log.d(TAG, " s_netType:" + s_netType + " s_netConfig:" + s_netConfig);
            mMasterWalletManager = new MasterWalletManager(rootPath, s_netType, s_netConfig, s_dataRootPath);
            mMasterWalletManager.SetLogLevel(s_logLevel);

            walletSemaphore = new Semaphore(1);
            cc.success("");
        } catch (WalletException e) {
            mMasterWalletManager = null;
            exceptionProcess(e, cc, "init MasterWalletManager error");
        }
    }

    public void destroy(JSONArray args, CallbackContext cc) throws JSONException {
        try {
          destroyMasterWalletManager();
          cc.success("");
      } catch (WalletException e) {
          exceptionProcess(e, cc, "destroy MasterWalletManager error");
      }
    }

    // args[0]: String language
    public void generateMnemonic(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String language = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        if (mMasterWalletManager == null) {
            errorProcess(cc, errCodeInvalidMasterWalletManager, "Master wallet manager has not initialize");
            return;
        }

        try {
            String mnemonic = mMasterWalletManager.GenerateMnemonic(language, 12);
            cc.success(mnemonic);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Generate mnemonic in '" + language + "'");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String mnemonic
    // args[2]: String phrasePassword
    // args[3]: String payPassword
    // args[4]: boolean singleAddress
    public void createMasterWallet(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String mnemonic = args.getString(idx++);
        String phrasePassword = args.getString(idx++);
        String payPassword = args.getString(idx++);
        boolean singleAddress = args.getBoolean(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = mMasterWalletManager.CreateMasterWallet(masterWalletID, mnemonic,
                    phrasePassword, payPassword, singleAddress);

            if (masterWallet == null) {
                errorProcess(cc, errCodeCreateMasterWallet, "Create " + formatWalletName(masterWalletID));
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create " + formatWalletName(masterWalletID));
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String singlePrivateKey
    // args[2]: String password
    public void createMasterWalletWithPrivKey(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String singlePrivateKey = args.getString(idx++);
        String password = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = mMasterWalletManager.CreateMasterWallet(masterWalletID, singlePrivateKey, password);

            if (masterWallet == null) {
                errorProcess(cc, errCodeCreateMasterWallet, "Create " + formatWalletName(masterWalletID) + " with priv key");
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create " + formatWalletName(masterWalletID) + " with priv key");
        }
    }

    public void createMultiSignMasterWallet(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String privKey = null;

        String masterWalletID = args.getString(idx++);
        String publicKeys = args.getString(idx++);
        int m = args.getInt(idx++);
        long timestamp = args.getLong(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            // TODO:: String masterWalletID, String coSigners, int requiredSignCount,
            // boolean singleAddress, boolean compatible, long timestamp
            MasterWallet masterWallet = null; // mMasterWalletManager.CreateMultiSignMasterWallet(
            // masterWalletID, publicKeys, m, timestamp);

            if (masterWallet == null) {
                errorProcess(cc, errCodeCreateMasterWallet, "Create multi sign " + formatWalletName(masterWalletID));
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create multi sign " + formatWalletName(masterWalletID));
        }
    }

    public void createMultiSignMasterWalletWithPrivKey(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String privKey = args.getString(idx++);
        String payPassword = args.getString(idx++);
        String publicKeys = args.getString(idx++);
        int m = args.getInt(idx++);
        long timestamp = args.getLong(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = null;
            // mMasterWalletManager.CreateMultiSignMasterWallet(
            // masterWalletID, privKey, payPassword, publicKeys, m, timestamp);

            if (masterWallet == null) {
                errorProcess(cc, errCodeCreateMasterWallet,
                        "Create multi sign " + formatWalletName(masterWalletID) + " with private key");
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create multi sign " + formatWalletName(masterWalletID) + " with private key");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String mnemonic
    // args[2]: String phrasePassword
    // args[3]: String payPassword
    // args[4]: String coSignersJson
    // args[5]: int requiredSignCount
    public void createMultiSignMasterWalletWithMnemonic(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String mnemonic = args.getString(idx++);
        String phrasePassword = args.getString(idx++);
        String payPassword = args.getString(idx++);
        String publicKeys = args.getString(idx++);
        int m = args.getInt(idx++);
        long timestamp = args.getLong(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = null;
            // mMasterWalletManager.CreateMultiSignMasterWallet(
            // masterWalletID, mnemonic, phrasePassword, payPassword, publicKeys, m,
            // timestamp);

            if (masterWallet == null) {
                errorProcess(cc, errCodeCreateMasterWallet,
                        "Create multi sign " + formatWalletName(masterWalletID) + " with mnemonic");
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create multi sign " + formatWalletName(masterWalletID) + " with mnemonic");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String keystoreContent
    // args[2]: String backupPassword
    // args[3]: String payPassword
    public void importWalletWithKeystore(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String keystoreContent = args.getString(idx++);
        String backupPassword = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = mMasterWalletManager.ImportWalletWithKeystore(masterWalletID, keystoreContent,
                    backupPassword, payPassword);
            if (masterWallet == null) {
                errorProcess(cc, errCodeImportFromKeyStore,
                        "Import " + formatWalletName(masterWalletID) + " with keystore");
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Import " + formatWalletName(masterWalletID) + " with keystore");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String mnemonic
    // args[2]: String phrasePassword
    // args[3]: String payPassword
    // args[4]: boolean singleAddress
    public void importWalletWithMnemonic(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String mnemonic = args.getString(idx++);
        String phrasePassword = args.getString(idx++);
        String payPassword = args.getString(idx++);
        boolean singleAddress = args.getBoolean(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = mMasterWalletManager.ImportWalletWithMnemonic(masterWalletID, mnemonic,
                    phrasePassword, payPassword, singleAddress, 0);
            if (masterWallet == null) {
                errorProcess(cc, errCodeImportFromMnemonic,
                        "Import " + formatWalletName(masterWalletID) + " with mnemonic");
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Import " + formatWalletName(masterWalletID) + " with mnemonic");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String seed
    // args[2]: String payPassword
    // args[3]: boolean singleAddress
    // args[4]: String mnemonic
    // args[5]: String phrasePassword
    public void importWalletWithSeed(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String seed = args.getString(idx++);
        String payPassword = args.getString(idx++);
        boolean singleAddress = args.getBoolean(idx++);
        String mnemonic = args.getString(idx++);
        String phrasePassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = mMasterWalletManager.ImportWalletWithSeed(masterWalletID, seed, payPassword,
                    singleAddress, mnemonic, phrasePassword);
            if (masterWallet == null) {
                errorProcess(cc, errCodeImportFromMnemonic,
                        "Import " + formatWalletName(masterWalletID) + " with seed");
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Import " + formatWalletName(masterWalletID) + " with mnemonic");
        }
    }

    public void getAllMasterWallets(JSONArray args, CallbackContext cc) throws JSONException {
        try {
            ArrayList<MasterWallet> masterWalletList = mMasterWalletManager.GetAllMasterWallets();
            JSONArray masterWalletListJson = new JSONArray();

            for (int i = 0; i < masterWalletList.size(); i++) {
                masterWalletListJson.put(masterWalletList.get(i).GetID());
            }
            cc.success(masterWalletListJson.toString());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get all master wallets");
        }
    }

    // args[0]: String masterWalletID
    public void getMasterWallet(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID));
        }
    }

    // args[0]: String masterWalletID
    public void destroyWallet(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;

        String masterWalletID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        new Thread(() -> {
            try {
                walletSemaphore.acquire();

                MasterWallet masterWallet = getIMasterWallet(masterWalletID);
                if (masterWallet == null) {
                    errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                    return;
                }

                mMasterWalletManager.DestroyWallet(masterWalletID);

                cc.success("Destroy " + formatWalletName(masterWalletID) + " OK");
            } catch (Exception e) {
                exceptionProcess(e, cc, "Destroy " + formatWalletName(masterWalletID));
            }
            walletSemaphore.release();
        }).start();
    }

    public void getVersion(JSONArray args, CallbackContext cc) throws JSONException {
        if (mMasterWalletManager == null) {
            errorProcess(cc, errCodeInvalidMasterWalletManager, "Master wallet manager has not initialize");
            return;
        }

        String version = mMasterWalletManager.GetVersion();
        cc.success(version);
    }

    // args[0]: String log level
    public void setLogLevel(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String loglevel = args.getString(idx++);
        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        s_logLevel = loglevel;
        if (mMasterWalletManager != null) {
            mMasterWalletManager.SetLogLevel(loglevel);
        }

        cc.success("SetLogLevel OK");
    }

    // args[0]: String network type
    // args[1]: String network config, only for private network.
    public void setNetwork(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String networkType = args.getString(idx++);
        String networkConfig = args.getString(idx++);
        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        s_netType = networkType;
        s_netConfig = networkConfig;

        cc.success("");
    }

    // args[0]: String masterWalletID
    public void getMasterWalletBasicInfo(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            cc.success(masterWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID) + " basic info");
        }
    }

    // args[0]: String masterWalletID
    public void getAllSubWallets(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            ArrayList<SubWallet> subWalletList = masterWallet.GetAllSubWallets();

            JSONArray subWalletJsonArray = new JSONArray();
            for (int i = 0; i < subWalletList.size(); i++) {
                subWalletJsonArray.put(subWalletList.get(i).GetChainID());
            }

            cc.success(subWalletJsonArray.toString());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + masterWalletID + " all subwallets");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: long feePerKb
    public void createSubWallet(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            SubWallet subWallet = masterWallet.CreateSubWallet(chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeCreateSubWallet, "Create " + formatWalletName(masterWalletID, chainID));
                return;
            }

            cc.success(subWallet.GetBasicInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create " + formatWalletName(masterWalletID, chainID));
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String backupPassword
    // args[2]: String payPassword
    public void exportWalletWithKeystore(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String backupPassword = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            String keystore = masterWallet.ExportKeystore(backupPassword, payPassword);

            cc.success(keystore);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Export " + formatWalletName(masterWalletID) + "to keystore");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String payPassword
    public void exportWalletWithMnemonic(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            String mnemonic = masterWallet.ExportMnemonic(payPassword);

            cc.success(mnemonic);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Export " + masterWalletID + " to mnemonic");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String payPassword
    public void exportWalletWithSeed(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            String seed = masterWallet.ExportSeed(payPassword);

            cc.success(seed);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Export " + masterWalletID + " to seed");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String payPassword
    public void exportWalletWithPrivateKey(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            String mnemonic = masterWallet.ExportPrivateKey(payPassword);

            cc.success(mnemonic);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Export " + masterWalletID + " to private");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String passPhrase
    // args[2]: String payPassword
    public void verifyPassPhrase(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String passPhrase = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            masterWallet.VerifyPassPhrase(passPhrase, payPassword);
            cc.success("VerifyPassPhrase OK");
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID) + " verify passPhrase");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String payPassword
    public void verifyPayPassword(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            masterWallet.VerifyPayPassword(payPassword);
            cc.success("verify PayPassword OK");
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID) + " verify PayPassword");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void destroySubWallet(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }
            SubWallet subWallet = masterWallet.GetSubWallet(chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            masterWallet.DestroyWallet(subWallet);

            cc.success("Destroy " + formatWalletName(masterWalletID, chainID) + " OK");
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Destroy " + formatWalletName(masterWalletID, chainID));
        }
    }

    // args[0]: String masterWalletID
    public void getPubKeyInfo(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            String pubkeyInfo = masterWallet.GetPubKeyInfo();
            cc.success(pubkeyInfo);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID) + " Get PubKey Info");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String address
    public void isAddressValid(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String addr = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            Boolean valid = masterWallet.IsAddressValid(addr);
            JSONObject result = new JSONObject();
            result.put("isValid", valid);

            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Check address valid of " + formatWalletName(masterWalletID));
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String address
    public void isSubWalletAddressValid(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String address = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            Boolean valid = masterWallet.IsSubWalletAddressValid(chainID, address);
            JSONObject result = new JSONObject();
            result.put("isValid", valid);

            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Check address valid of " + formatWalletName(masterWalletID, chainID));
        }
    }

    // args[0]: String masterWalletID
    public void getSupportedChains(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            String[] supportedChains = masterWallet.GetSupportedChains();
            JSONArray supportedChainsJson = new JSONArray();
            for (int i = 0; i < supportedChains.length; i++) {
                supportedChainsJson.put(supportedChains[i]);
            }

            cc.success(supportedChainsJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID) + " get support chain");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String oldPassword
    // args[2]: String newPassword
    public void changePassword(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String oldPassword = args.getString(idx++);
        String newPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            masterWallet.ChangePassword(oldPassword, newPassword);
            cc.success("Change password OK");
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID) + " change password");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String mnemonic
    // args[2]: String passphrase
    // args[3]: String newPassword
    public void resetPassword(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String mnemonic = args.getString(idx++);
        String passphrase = args.getString(idx++);
        String newPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Get " + formatWalletName(masterWalletID));
                return;
            }

            masterWallet.ResetPassword(mnemonic, passphrase, newPassword);
            cc.success("Reset password OK");
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID) + " reset password");
        }
    }

    // Subwallet

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: int start
    // args[3]: int count
    // args[4]: bool internal
    public void getAddresses(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);
        boolean internal = args.getBoolean(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }
            String allAddresses = subWallet.GetAddresses(start, count, internal);
            cc.success(allAddresses);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " all addresses");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: int start
    // args[3]: int count
    // args[4]: bool internal
    public void getPublicKeys(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);
        boolean internal = args.getBoolean(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }
            String allAddresses = subWallet.GetPublicKeys(start, count, internal);
            cc.success(allAddresses);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " all publickeys");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String inputs
    // args[3]: String outputs
    // args[4]: String fee
    // args[5]: String memo
    public void createTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String outputs = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            ElastosBaseSubWallet subWallet = (ElastosBaseSubWallet) getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            String tx = subWallet.CreateTransaction(inputs, outputs, fee, memo);

            cc.success(tx);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create " + formatWalletName(masterWalletID, chainID) + " transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String rawTransaction
    // args[3]: String payPassword
    // return: String txJson
    public void signTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String rawTransaction = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            String result = subWallet.SignTransaction(rawTransaction, payPassword);
            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Sign " + formatWalletName(masterWalletID, chainID) + " transaction");
        }
    }

    public void signDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String address = args.getString(idx++);
        String digest = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }
            String result = subWallet.SignDigest(address, digest, payPassword);
            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " signDigest");
        }
    }

    public void verifyDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String publicKey = args.getString(idx++);
        String digest = args.getString(idx++);
        String signature = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }
            String result = subWallet.SignDigest(publicKey, digest, signature);
            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " verifyDigest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String txJson
    public void getTransactionSignedInfo(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String rawTxJson = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            ElastosBaseSubWallet subWallet = (ElastosBaseSubWallet) getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            String resultJson = subWallet.GetTransactionSignedInfo(rawTxJson);
            cc.success(resultJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " tx signed info");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String txJson
    public void convertToRawTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String txJson = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            ElastosBaseSubWallet subWallet = (ElastosBaseSubWallet) getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            String result = subWallet.ConvertToRawTransaction(txJson);
            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Convert " + formatWalletName(masterWalletID, chainID) + " To Raw Transactions");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String inputs
    // args[3]: String payloadJson
    // args[4]: String memo
    // args[5]: String fee  [option]
    public void createIdTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String memo = args.getString(idx++);
        String fee = args.isNull(idx) ? "10000" : args.getString(idx);

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof IDChainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + "' is not instance of IDChainSubWallet");
                return;
            }

            IDChainSubWallet idchainSubWallet = (IDChainSubWallet) subWallet;

            cc.success(idchainSubWallet.CreateIDTransaction(inputs, payloadJson, memo, fee));
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create ID transaction");
        }
    }

    private IDChainSubWallet getIDChainSubWallet(String masterWalletID) {
        SubWallet subWallet = getSubWallet(masterWalletID, IDChain);

        if ((subWallet instanceof IDChainSubWallet)) {
            return (IDChainSubWallet) subWallet;
        }
        return null;

    }

    public void getDID(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);
        boolean internal = args.getBoolean(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            IDChainSubWallet idChainSubWallet = getIDChainSubWallet(masterWalletID);
            if (idChainSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, IDChain));
                return;
            }
            String did = idChainSubWallet.GetDID(start, count, internal);

            cc.success(did);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " getAllDID");
        }
    }

    public void getCID(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);
        boolean internal = args.getBoolean(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            IDChainSubWallet idChainSubWallet = getIDChainSubWallet(masterWalletID);
            if (idChainSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, IDChain));
                return;
            }
            String did = idChainSubWallet.GetCID(start, count, internal);

            cc.success(did);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " getAllCID");
        }
    }

    public void didSign(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String did = args.getString(idx++);
        String message = args.getString(idx++);
        String payPassword = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            IDChainSubWallet idChainSubWallet = getIDChainSubWallet(masterWalletID);
            if (idChainSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, IDChain));
                return;
            }
            String result = idChainSubWallet.Sign(did, message, payPassword);
            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " didSign");
        }
    }

    public void verifySignature(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String publicKey = args.getString(idx++);
        String message = args.getString(idx++);
        String signature = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            IDChainSubWallet idChainSubWallet = getIDChainSubWallet(masterWalletID);
            if (idChainSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, IDChain));
                return;
            }
            Boolean result = idChainSubWallet.VerifySignature(publicKey, message, signature);
            cc.success(result.toString());
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " verifySignature");
        }
    }

    public void getPublicKeyDID(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String pubkey = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            IDChainSubWallet idChainSubWallet = getIDChainSubWallet(masterWalletID);
            if (idChainSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, IDChain));
                return;
            }
            String did = idChainSubWallet.GetPublicKeyDID(pubkey);
            cc.success(did);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " GetPublicKeyDID");
        }
    }

    public void getPublicKeyCID(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String pubkey = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            IDChainSubWallet idChainSubWallet = getIDChainSubWallet(masterWalletID);
            if (idChainSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, IDChain));
                return;
            }
            String did = idChainSubWallet.GetPublicKeyCID(pubkey);
            cc.success(did);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " GetPublicKeyCID");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String targetAddress
    // args[3]: String amount
    // args[4]: int amountUnit
    // args[5]: String gasPrice
    // args[6]: int gasPriceUnit
    // args[7]: String gasLimit
    // args[8]: long nonce
    public void createTransfer(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String targetAddress = args.getString(idx++);
        String amount = args.getString(idx++);
        int amountUnit = args.getInt(idx++);
        String gasPrice = args.getString(idx++);
        int gasPriceUnit = args.getInt(idx++);
        String gasLimit = args.getString(idx++);
        long nonce = args.getLong(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            EthSidechainSubWallet ethscSubWallet = getEthSidechainSubWallet(masterWalletID, chainID);
            if (ethscSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }
            cc.success(ethscSubWallet.CreateTransfer(targetAddress, amount, amountUnit, gasPrice, gasPriceUnit, gasLimit, nonce));
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create transfer");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String targetAddress
    // args[2]: String amount
    // args[3]: int amountUnit
    // args[4]: String gasPrice
    // args[5]: int gasPriceUnit
    // args[6]: String gasLimit
    // args[7]: String data
    // args[8]: int nonce
    public void createTransferGeneric(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String targetAddress = args.getString(idx++);
        String amount = args.getString(idx++);
        int amountUnit = args.getInt(idx++);
        String gasPrice = args.getString(idx++);
        int gasPriceUnit = args.getInt(idx++);
        String gasLimit = args.getString(idx++);
        String data = args.getString(idx++);
        long nonce = args.getLong(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            EthSidechainSubWallet ethscSubWallet = getEthSidechainSubWallet(masterWalletID, chainID);
            if (ethscSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }
            cc.success(ethscSubWallet.CreateTransferGeneric(targetAddress, amount, amountUnit, gasPrice, gasPriceUnit, gasLimit, data, nonce));
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create transfer generic");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[1]: String payPassword
    public void exportETHSCPrivateKey(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String password = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            EthSidechainSubWallet ethscSubWallet = getEthSidechainSubWallet(masterWalletID, chainID);
            if (ethscSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            String privatekey = ethscSubWallet.ExportPrivateKey(password);

            cc.success(privatekey);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Export " + masterWalletID + " to private");
        }
    }

    // MainchainSubWallet

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: int version
    // args[3]: String inputs
    // args[4]: String sideChainID
    // args[5]: String amount
    // args[6]: String sideChainAddress
    // args[7]: String lockAddress
    // args[8]: String fee
    // args[9]: String memo
    public void createDepositTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        int version = args.getInt(idx++);
        String inputs = args.getString(idx++);
        String sideChainID = args.getString(idx++);
        String amount = args.getString(idx++);
        String sideChainAddress = args.getString(idx++);
        String lockAddress = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateDepositTransaction(version, inputs, sideChainID, amount,
                    sideChainAddress, lockAddress, fee, memo);

            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create deposit transaction");
        }
    }

    // -- vote

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String inputs
    // args[3]: String votes JSONObject
    // args[4]: String fee
    // args[5]: String memo
    public void createVoteTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String voteContents = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateVoteTransaction(inputs, voteContents, fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create vote transaction");
        }
    }

    // -- Producer

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String publicKey
    // args[3]: String nodePublicKey
    // args[4]: String nickName
    // args[5]: String url
    // args[6]: String IPAddress
    // args[7]: long location
    // args[8]: String payPasswd
    public void generateProducerPayload(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String publicKey = args.getString(idx++);
        String nodePublicKey = args.getString(idx++);
        String nickName = args.getString(idx++);
        String url = args.getString(idx++);
        String IPAddress = args.getString(idx++);
        long location = args.getLong(idx++);
        String payPasswd = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String payloadJson = mainchainSubWallet.GenerateProducerPayload(publicKey, nodePublicKey, nickName, url,
                    IPAddress, location, payPasswd);
            cc.success(payloadJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " generate producer payload");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String publicKey
    // args[3]: String payPasswd
    public void generateCancelProducerPayload(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String publicKey = args.getString(idx++);
        String payPasswd = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String payloadJson = mainchainSubWallet.GenerateCancelProducerPayload(publicKey, payPasswd);
            cc.success(payloadJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " generate cancel producer payload");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String inputs
    // args[3]: String payloadJson
    // args[4]: String amount
    // args[5]: String memo
    public void createRegisterProducerTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String amount = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateRegisterProducerTransaction(inputs, payloadJson, amount,
                    fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create register producer transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String inputs
    // args[3]: String payloadJson
    // args[4]: String memo
    public void createUpdateProducerTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateUpdateProducerTransaction(inputs, payloadJson, fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create update producer transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String inputs
    // args[3]: String payloadJson
    // args[4]: String memo
    public void createCancelProducerTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateCancelProducerTransaction(inputs, payloadJson, fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create cancel producer transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String amount
    // args[3]: String memo
    public void createRetrieveDepositTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String amount = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateRetrieveDepositTransaction(inputs, amount, fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create retrieve deposit transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void getOwnerPublicKey(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String publicKey = mainchainSubWallet.GetOwnerPublicKey();
            cc.success(publicKey);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get public key for vote");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void getOwnerAddress(JSONArray args, CallbackContext cc) throws JSONException {
      int idx = 0;
      String masterWalletID = args.getString(idx++);
      String chainID = args.getString(idx++);

      if (args.length() != idx) {
          errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
          return;
      }

      try {
          SubWallet subWallet = getSubWallet(masterWalletID, chainID);
          if (subWallet == null) {
              errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
              return;
          }

          if (!(subWallet instanceof MainchainSubWallet)) {
              errorProcess(cc, errCodeSubWalletInstance,
                      formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
              return;
          }

          MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
          String address = mainchainSubWallet.GetOwnerAddress();
          cc.success(address);
      } catch (WalletException e) {
          exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get owner address");
      }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void getOwnerDepositAddress(JSONArray args, CallbackContext cc) throws JSONException {
      int idx = 0;
      String masterWalletID = args.getString(idx++);
      String chainID = args.getString(idx++);

      if (args.length() != idx) {
          errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
          return;
      }

      try {
          SubWallet subWallet = getSubWallet(masterWalletID, chainID);
          if (subWallet == null) {
              errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
              return;
          }

          if (!(subWallet instanceof MainchainSubWallet)) {
              errorProcess(cc, errCodeSubWalletInstance,
                      formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
              return;
          }

          MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
          String address = mainchainSubWallet.GetOwnerDepositAddress();
          cc.success(address);
      } catch (WalletException e) {
          exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get owner deposit address");
      }
    }

    // -- CRC

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void getCRDepositAddress(JSONArray args, CallbackContext cc) throws JSONException {
      int idx = 0;
      String masterWalletID = args.getString(idx++);
      String chainID = args.getString(idx++);

      if (args.length() != idx) {
          errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
          return;
      }

      try {
          SubWallet subWallet = getSubWallet(masterWalletID, chainID);
          if (subWallet == null) {
              errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
              return;
          }

          if (!(subWallet instanceof MainchainSubWallet)) {
              errorProcess(cc, errCodeSubWalletInstance,
                      formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
              return;
          }

          MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
          String address = mainchainSubWallet.GetCRDepositAddress();
          cc.success(address);
      } catch (WalletException e) {
          exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get owner deposit address");
      }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String crPublickKey
    // args[3]: String did
    // args[4]: String nickName
    // args[5]: String url
    // args[6]: long location
    public void generateCRInfoPayload(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String crPublicKey = args.getString(idx++);
        String did = args.getString(idx++);
        String nickName = args.getString(idx++);
        String url = args.getString(idx++);
        long location = args.getLong(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String payloadJson = mainchainSubWallet.GenerateCRInfoPayload(crPublicKey, did, nickName, url, location);
            cc.success(payloadJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " generate CR Info payload");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String CID
    public void generateUnregisterCRPayload(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String did = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String payloadJson = mainchainSubWallet.GenerateUnregisterCRPayload(did);
            cc.success(payloadJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " generate unregister CR payload");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String inputs
    // args[3]: String payloadJSON
    // args[4]: String amount
    // args[5]: String memo
    public void createRegisterCRTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String amount = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateRegisterCRTransaction(inputs, payloadJson, amount,
                    fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create register CR transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String inputs
    // args[3]: String payloadJSON
    // args[4]: String memo
    public void createUpdateCRTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateUpdateCRTransaction(inputs, payloadJson, fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create update CR transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String inputs
    // args[3]: String payloadJSON
    // args[4]: String memo
    public void createUnregisterCRTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateUnregisterCRTransaction(inputs, payloadJson, fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create unregister CR transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String inputs
    // args[3]: String fee
    // args[4]: String memo
    public void createRetrieveCRDepositTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String amount = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateRetrieveCRDepositTransaction(inputs, amount, fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create retrieve CR deposit transaction");
        }
    }


    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String payload
    public void CRCouncilMemberClaimNodeDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CRCouncilMemberClaimNodeDigest(payload);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " CRCouncilMember claim node digest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String payload
    // args[3]: String memo
    public void createCRCouncilMemberClaimNodeTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String txJson = mainchainSubWallet.CreateCRCouncilMemberClaimNodeTransaction(inputs, payload, fee, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create CRCouncilMember claim node digest transaction");
        }
    }

    // -- Proposal

    //Proposal
    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    public void proposalOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " ProposalOwnerDigest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    public void proposalCRCouncilMemberDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalCRCouncilMemberDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " ProposalCRCouncilMemberDigest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    public void calculateProposalHash(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CalculateProposalHash(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " CalculateProposalHash");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String crSignedProposal
    // args[3]: String memo
    public void createProposalTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateProposalTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " CreateCRCProposalTransaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    public void proposalReviewDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalReviewDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " ProposalReviewDigest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    // args[3]: String memo
    public void createProposalReviewTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateProposalReviewTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createProposalReviewTransaction");
        }
    }

    // -- Proposal Tracking

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    public void proposalTrackingOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalTrackingOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " proposalTrackingOwnerDigest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    public void proposalTrackingNewOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalTrackingNewOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " proposalTrackingNewOwnerDigest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    public void proposalTrackingSecretaryDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalTrackingSecretaryDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " proposalTrackingSecretaryDigest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String leaderSignedProposalTracking
    // args[3]: String memo
    public void createProposalTrackingTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateProposalTrackingTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " CreateProposalTrackingTransaction");
        }
    }

    // -- Proposal Secretary General Election
    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload Proposal payload.
    public void proposalSecretaryGeneralElectionDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalSecretaryGeneralElectionDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " proposalSecretaryGeneralElectionDigest");
        }
    }

    public void proposalSecretaryGeneralElectionCRCouncilMemberDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalSecretaryGeneralElectionCRCouncilMemberDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " proposalSecretaryGeneralElectionCRCouncilMemberDigest");
        }
    }

    public void createSecretaryGeneralElectionTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateSecretaryGeneralElectionTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createSecretaryGeneralElectionTransaction");
        }
    }

    // -- Proposal Change Owner
    public void proposalChangeOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalChangeOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " proposalChangeOwnerDigest");
        }
    }

    public void proposalChangeOwnerCRCouncilMemberDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalChangeOwnerCRCouncilMemberDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " proposalChangeOwnerCRCouncilMemberDigest");
        }
    }

    public void createProposalChangeOwnerTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateProposalChangeOwnerTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createProposalChangeOwnerTransaction");
        }
    }

    // -- Proposal Terminate Proposal
    public void terminateProposalOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.TerminateProposalOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " terminateProposalOwnerDigest");
        }
    }

    public void terminateProposalCRCouncilMemberDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.TerminateProposalCRCouncilMemberDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " terminateProposalCRCouncilMemberDigest");
        }
    }

    public void createTerminateProposalTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateTerminateProposalTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createTerminateProposalTransaction");
        }
    }

    // -- Reserve Custom ID
    public void reserveCustomIDOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ReserveCustomIDOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " reserveCustomIDOwnerDigest");
        }
    }

    public void reserveCustomIDCRCouncilMemberDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ReserveCustomIDCRCouncilMemberDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " reserveCustomIDCRCouncilMemberDigest");
        }
    }

    public void createReserveCustomIDTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateReserveCustomIDTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createReserveCustomIDTransaction");
        }
    }

    // -- Receive Custom ID
    public void receiveCustomIDOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ReceiveCustomIDOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " receiveCustomIDOwnerDigest");
        }
    }

    public void receiveCustomIDCRCouncilMemberDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ReceiveCustomIDCRCouncilMemberDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " receiveCustomIDCRCouncilMemberDigest");
        }
    }

    public void createReceiveCustomIDTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateReceiveCustomIDTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createReceiveCustomIDTransaction");
        }
    }

    // -- Change Custom ID Fee
    public void changeCustomIDFeeOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ChangeCustomIDFeeOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " changeCustomIDFeeOwnerDigest");
        }
    }

    public void changeCustomIDFeeCRCouncilMemberDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ChangeCustomIDFeeCRCouncilMemberDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " changeCustomIDFeeCRCouncilMemberDigest");
        }
    }

    public void createChangeCustomIDFeeTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateChangeCustomIDFeeTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createChangeCustomIDFeeTransaction");
        }
    }

    // -- Proposal Withdraw

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload
    public void proposalWithdrawDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.ProposalWithdrawDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " proposalWithdrawDigest");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String payload Proposal payload.
    // args[3]: String memo Remarks string. Can be empty string
    public void createProposalWithdrawTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateProposalWithdrawTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createProposalWithdrawTransaction");
        }
    }

    // -- Proposal Register side-chain
    public void registerSidechainOwnerDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.RegisterSidechainOwnerDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " registerSidechainOwnerDigest");
        }
    }

    public void registerSidechainCRCouncilMemberDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String payload = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.RegisterSidechainCRCouncilMemberDigest(payload);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc,
                    formatWalletName(masterWalletID, chainID) + " registerSidechainCRCouncilMemberDigest");
        }
    }

    public void createRegisterSidechainTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String payload = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof MainchainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of MainchainSubWallet");
                return;
            }

            MainchainSubWallet mainchainSubWallet = (MainchainSubWallet) subWallet;
            String stringJson = mainchainSubWallet.CreateRegisterSidechainTransaction(inputs, payload, fee, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createRegisterSidechainTransaction");
        }
    }

    // SidechainSubWallet

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String inputs
    // args[3]: String amount
    // args[4]: String mainchainAdress
    // args[5]: String fee
    // args[6]: String memo
    public void createWithdrawTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String amount = args.getString(idx++);
        String mainchainAddress = args.getString(idx++);
        String fee = args.getString(idx++);
        String memo = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            if (!(subWallet instanceof SidechainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of SidechainSubWallet");
                return;
            }

            SidechainSubWallet sidechainSubWallet = (SidechainSubWallet) subWallet;
            String tx = sidechainSubWallet.CreateWithdrawTransaction(inputs, amount, mainchainAddress, fee, memo);

            cc.success(tx);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create withdraw transaction");
        }
    }

    // BTCSubWallet

    // args[0]: String masterWalletID
    // args[1]: int start
    // args[2]: int count
    // args[3]: bool internal
    public void getLegacyAddresses(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);
        boolean internal = args.getBoolean(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            BTCSubWallet subWallet = getBTCSubWallet(masterWalletID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, "BTC"));
                return;
            }
            String allAddresses = subWallet.GetLegacyAddresses(start, count, internal);
            cc.success(allAddresses);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, "BTC") + " legacy addresses");
        }
    }

    // args[0]: String masterWalletID
    // args[2]: String inputs
    // args[3]: String outputs
    // args[4]: String changeAddress
    // args[5]: String feePerKB
    public void createBTCTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String inputs = args.getString(idx++);
        String outputs = args.getString(idx++);
        String changeAddress = args.getString(idx++);
        String feePerKB = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            BTCSubWallet subWallet = (BTCSubWallet) getBTCSubWallet(masterWalletID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, "BTC"));
                return;
            }

            String tx = subWallet.CreateTransaction(inputs, outputs, changeAddress, feePerKB);
            cc.success(tx);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create " + formatWalletName(masterWalletID, "BTC") + " transaction");
        }
    }
}
