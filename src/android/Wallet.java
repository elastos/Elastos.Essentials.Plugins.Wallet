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

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;

import org.elastos.spvcore.EthSidechainSubWallet;
import org.elastos.spvcore.ISubWalletListener;
import org.elastos.spvcore.MasterWallet;
import org.elastos.spvcore.SubWallet;
import org.elastos.spvcore.MainchainSubWallet;
import org.elastos.spvcore.IDChainSubWallet;
import org.elastos.spvcore.SidechainSubWallet;
import org.elastos.spvcore.MasterWalletManager;
import org.elastos.spvcore.SubWalletCallback;
import org.elastos.spvcore.WalletException;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.concurrent.Semaphore;

import android.util.Base64;
import android.util.Log;

/**
 * wallet webview jni
 */
public class Wallet extends CordovaPlugin {

    private static final String TAG = "Wallet";

    private static HashMap<Integer, CallbackContext> subwalletListenerMap = new HashMap<>();
    private HashMap<String, InputStream> backupFileReaderMap = new HashMap<>();
    private HashMap<String, Integer> backupFileReaderOffsetsMap = new HashMap<>(); // Current read offset byte position for each active reader
    private HashMap<String, OutputStream> backupFileWriterMap = new HashMap<>();

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
    public static final String ETHSC = "ETHSC";

    private static String s_ethscjsonrpcUrl = "http://api.elastos.io:20636";
    private static String s_ethscapimiscUrl = "http://api.elastos.io:20634";
    private static String s_ethscGetTokenListUrl = "https://eth.elastos.io";

    private static String s_dataRootPath = "";
    private static String s_netType = "MainNet";
    private static String s_netConfig = "";
    private static String s_logLevel = "debug";

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
        Log.i(TAG, "onPause");
        // if (mMasterWalletManager != null) {
        // mMasterWalletManager.SaveConfigs();
        // }
        super.onPause(multitasking);
    }

    /**
     * Called when the activity will start interacting with the user.
     *
     * @param multitasking Flag indicating if multitasking is turned on for app
     */
    @Override
    public void onResume(boolean multitasking) {
        Log.i(TAG, "onResume");
        super.onResume(multitasking);
    }

    /**
     * Called when the activity is becoming visible to the user.
     */
    @Override
    public void onStart() {
        Log.i(TAG, "onStart");
        super.onStart();
    }

    /**
     * Called when the activity is no longer visible to the user.
     */
    @Override
    public void onStop() {
        Log.i(TAG, "onStop");
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
            int cordovaHashCode = this.cordova.hashCode();
            subwalletListenerMap.remove(cordovaHashCode);

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
        if (mMasterWalletManager != null) {
            subwalletListenerMap.clear();

            try {
                walletSemaphore.acquire();

                ArrayList<MasterWallet> masterWalletList = mMasterWalletManager.GetAllMasterWallets();
                for (int i = 0; i < masterWalletList.size(); i++) {
                    MasterWallet masterWallet = masterWalletList.get(i);
                    ArrayList<SubWallet> subWallets = masterWallet.GetAllSubWallets();
                    for (int j = 0; j < subWallets.size(); ++j) {
                        subWallets.get(j).SyncStop();
                        subWallets.get(j).RemoveCallback();
                    }
                }
                mMasterWalletManager.Dispose();
                mMasterWalletManager = null;
                Log.i(TAG, "destroyMasterWalletManager finished");
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            walletSemaphore.release();
        }
    }

    private void addWalletListener() {
        ArrayList<MasterWallet> masterWalletList = mMasterWalletManager.GetAllMasterWallets();
        for (int i = 0; i < masterWalletList.size(); i++) {
            String masterWalletID = masterWalletList.get(i).GetID();
            MasterWallet masterWallet = mMasterWalletManager.GetMasterWallet(masterWalletID);
            ArrayList<SubWallet> subWalletList = masterWallet.GetAllSubWallets();

            for (int j = 0; j < subWalletList.size(); j++) {
                String chainID = subWalletList.get(j).GetChainID();
                addSubWalletListener(masterWalletID, chainID);
                // subWalletList.get(j).SyncStart();
            }
        }
    }

    private void addSubWalletListener(String masterWalletID, String chainID) {
        SubWallet subWallet = getSubWallet(masterWalletID, chainID);
        if (subWallet == null) {
            return;
        }
        Log.d(TAG, "addSubWalletListener:" + masterWalletID + " " + chainID);
        subWallet.AddCallback(new SubWalletCallback(masterWalletID, chainID, s_ethscjsonrpcUrl, s_ethscapimiscUrl, new ISubWalletListener() {
            @Override
            public void sendResultSuccess(JSONObject jsonObject) {
                Log.d(TAG, jsonObject.toString());

                if (subwalletListenerMap.isEmpty()) return;

                PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, jsonObject);
                pluginResult.setKeepCallback(true);
                for(CallbackContext cc : subwalletListenerMap.values()){
                    cc.sendPluginResult(pluginResult);
                }
            }

            @Override
            public void sendResultError(String error) {
                if (subwalletListenerMap.isEmpty()) return;

                PluginResult pluginResult = new PluginResult(PluginResult.Status.JSON_EXCEPTION, error);
                pluginResult.setKeepCallback(true);
                for(CallbackContext cc : subwalletListenerMap.values()){
                    cc.sendPluginResult(pluginResult);
                }
            }
        }));
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
                case "exportWalletWithKeystore":
                    this.exportWalletWithKeystore(args, cc);
                    break;
                case "exportWalletWithMnemonic":
                    this.exportWalletWithMnemonic(args, cc);
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
                case "syncStart":
                    this.syncStart(args, cc);
                    break;
                case "syncStop":
                    this.syncStop(args, cc);
                    break;
                case "reSync":
                    this.reSync(args, cc);
                    break;
                case "getBalanceInfo":
                    this.getBalanceInfo(args, cc);
                    break;
                case "getBalance":
                    this.getBalance(args, cc);
                    break;
                case "createAddress":
                    this.createAddress(args, cc);
                    break;
                case "getAllAddress":
                    this.getAllAddress(args, cc);
                    break;
                case "getAllPublicKeys":
                    this.getAllPublicKeys(args, cc);
                    break;
                case "getBalanceWithAddress":
                    this.getBalanceWithAddress(args, cc);
                    break;
                case "createTransaction":
                    this.createTransaction(args, cc);
                    break;
                case "getAllUTXOs":
                    this.getAllUTXOs(args, cc);
                    break;
                case "createConsolidateTransaction":
                    this.createConsolidateTransaction(args, cc);
                    break;
                case "signTransaction":
                    this.signTransaction(args, cc);
                    break;
                case "getTransactionSignedInfo":
                    this.getTransactionSignedInfo(args, cc);
                    break;
                case "publishTransaction":
                    this.publishTransaction(args, cc);
                    break;
                case "getAllTransaction":
                    this.getAllTransaction(args, cc);
                    break;
                case "registerWalletListener":
                    this.registerWalletListener(args, cc);
                    break;
                case "removeWalletListener":
                    this.removeWalletListener(args, cc);
                    break;
                case "getLastBlockInfo":
                    this.getLastBlockInfo(args, cc);
                    break;

                // ID chain subwallet
                case "createIdTransaction":
                    this.createIdTransaction(args, cc);
                    break;
                case "getAllDID":
                    this.getAllDID(args, cc);
                    break;
                case "getAllCID":
                    this.getAllCID(args, cc);
                    break;
                case "didSign":
                    this.didSign(args, cc);
                    break;
                case "didSignDigest":
                    this.didSignDigest(args, cc);
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
                case "deleteTransfer":
                    this.deleteTransfer(args, cc);
                    break;
                case "getTokenTransactions":
                    this.getTokenTransactions(args, cc);
                    break;

                // Main chain subwallet
                case "createDepositTransaction":
                    this.createDepositTransaction(args, cc);
                    break;
                // -- vote
                case "createVoteProducerTransaction":
                    this.createVoteProducerTransaction(args, cc);
                    break;
                case "createVoteCRTransaction":
                    this.createVoteCRTransaction(args, cc);
                    break;
                case "createVoteCRCProposalTransaction":
                    this.createVoteCRCProposalTransaction(args, cc);
                    break;
                case "createImpeachmentCRCTransaction":
                    this.createImpeachmentCRCTransaction(args, cc);
                    break;
                case "getVotedProducerList":
                    this.getVotedProducerList(args, cc);
                    break;
                case "getVotedCRList":
                    this.getVotedCRList(args, cc);
                    break;
                case "getVoteInfo":
                    this.getVoteInfo(args, cc);
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
                case "getRegisteredProducerInfo":
                    this.getRegisteredProducerInfo(args, cc);
                    break;
                // -- CRC
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
                case "getRegisteredCRInfo":
                    this.getRegisteredCRInfo(args, cc);
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

                // -- Proposal Withdraw
                case "proposalWithdrawDigest":
                    this.proposalWithdrawDigest(args, cc);
                    break;
                case "createProposalWithdrawTransaction":
                    this.createProposalWithdrawTransaction(args, cc);
                    break;

                // Side chain subwallet
                case "createWithdrawTransaction":
                    this.createWithdrawTransaction(args, cc);
                    break;
                case "getGenesisAddress":
                    this.getGenesisAddress(args, cc);
                    break;

                // ERC20 Token list
                case "getERC20TokenList":
                    this.getERC20TokenList(args, cc);
                    break;

                // Backup and restore
                case "getBackupInfo":
                    this.getBackupInfo(args, cc);
                    break;
                case "getBackupFile":
                    this.getBackupFile(args, cc);
                    break;
                case "restoreBackupFile":
                    this.restoreBackupFile(args, cc);
                    break;
                case "backupFileReader_read":
                    this.backupFileReader_read(args, cc);
                    break;
                case "backupFileReader_close":
                    this.backupFileReader_close(args, cc);
                    break;
                case "backupFileWriter_write":
                    this.backupFileWriter_write(args, cc);
                    break;
                case "backupFileWriter_close":
                    this.backupFileWriter_close(args, cc);
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
            mMasterWalletManager = new MasterWalletManager(rootPath, s_netType, s_netConfig, s_dataRootPath);
            mMasterWalletManager.SetLogLevel(s_logLevel);
            addWalletListener();

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

                ArrayList<SubWallet> subWalletList = masterWallet.GetAllSubWallets();
                for (int i = 0; subWalletList != null && i < subWalletList.size(); i++) {
                    subWalletList.get(i).SyncStop();
                    subWalletList.get(i).RemoveCallback();
                    masterWallet.DestroyWallet(subWalletList.get(i));
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
    // args[2]: String json rpc Url
    // args[3]: String api misc Url
    public void setNetwork(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String networkType = args.getString(idx++);
        String networkConfig = args.getString(idx++);
        String jsonrpcUrl = args.getString(idx++);
        String apimiscUrl = args.getString(idx++);
        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        s_netType = networkType;
        s_netConfig = networkConfig;
        s_ethscjsonrpcUrl = jsonrpcUrl;
        s_ethscapimiscUrl = apimiscUrl;
        // TODO user set the s_ethscGetTokenListUrl?
        if ("TestNet".equals(s_netType)) {
            s_ethscGetTokenListUrl = "https://eth-testnet.elastos.io";
        } else {
            s_ethscGetTokenListUrl = "https://eth.elastos.io";
        }

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

            addSubWalletListener(masterWalletID, chainID);
            // subWallet.SyncStart();

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
        String backupPassword = args.getString(idx++);

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

            String mnemonic = masterWallet.ExportMnemonic(backupPassword);

            cc.success(mnemonic);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Export " + masterWalletID + " to mnemonic");
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

            subWallet.RemoveCallback();
            subWallet.SyncStop();
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

            masterWallet.GetPubKeyInfo();
            cc.success("GetPubKeyInfo OK");
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

    public void syncStart(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        new Thread(() -> {
            try {
                SubWallet subWallet = getSubWallet(masterWalletID, chainID);
                if (subWallet == null) {
                    errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                    return;
                }
                subWallet.SyncStart();
                cc.success("SyncStart OK");
            } catch (Exception e) {
                exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " sync start");
            }
        }).start();
    }

    public void syncStop(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        new Thread(() -> {
            try {
                SubWallet subWallet = getSubWallet(masterWalletID, chainID);
                if (subWallet == null) {
                    errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                    return;
                }
                subWallet.SyncStop();
                cc.success("SyncStop OK");
            } catch (Exception e) {
                exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " sync stop");
            }
        }).start();
    }

    public void reSync(JSONArray args, CallbackContext cc) throws JSONException {
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
            subWallet.Resync();
            cc.success("Resync OK");
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " resync");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void getBalanceInfo(JSONArray args, CallbackContext cc) throws JSONException {
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
            cc.success(subWallet.GetBalanceInfo());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " balance info");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void getBalance(JSONArray args, CallbackContext cc) throws JSONException {
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
                errorProcess(cc, errCodeInvalidSubWallet,
                        "Get " + formatWalletName(masterWalletID, chainID) + " balance");
                return;
            }

            cc.success(subWallet.GetBalance());
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " balance");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void createAddress(JSONArray args, CallbackContext cc) throws JSONException {
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

            String address = subWallet.CreateAddress();

            cc.success(address);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create " + formatWalletName(masterWalletID, chainID) + " address");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: int start
    // args[3]: int count
    // args[4]: bool internal
    public void getAllAddress(JSONArray args, CallbackContext cc) throws JSONException {
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
            String allAddresses = subWallet.GetAllAddress(start, count, internal);
            cc.success(allAddresses);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " all addresses");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: int start
    // args[3]: int count
    public void getAllPublicKeys(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);

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
            String allAddresses = subWallet.GetAllPublicKeys(start, count);
            cc.success(allAddresses);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " all publickeys");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String address
    public void getBalanceWithAddress(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String address = args.getString(idx++);
        int balanceType = args.getInt(idx++);

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

            String balance = subWallet.GetBalanceWithAddress(address);

            cc.success(balance);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " balance with address");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String fromAddress
    // args[3]: String targetAddress
    // args[4]: String amount
    // args[5]: String memo
    public void createTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String targetAddress = args.getString(idx++);
        String amount = args.getString(idx++);
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

            String tx = subWallet.CreateTransaction(fromAddress, targetAddress, amount, memo);

            cc.success(tx);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Create " + formatWalletName(masterWalletID, chainID) + " transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: int start
    // args[3]: int count
    // args[4]: String address
    // return: String all utxo in json format
    public void getAllUTXOs(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);
        String address = args.getString(idx++);

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

            String result = subWallet.GetAllUTXOs(start, count, address);
            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "get " + formatWalletName(masterWalletID, chainID) + " all UTXOs");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String memo
    // return: String txJson
    public void createConsolidateTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
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

            String result = subWallet.CreateConsolidateTransaction(memo);
            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "create " + formatWalletName(masterWalletID, chainID) + " Consolidate transaction");
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
            SubWallet subWallet = getSubWallet(masterWalletID, chainID);
            if (subWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, chainID));
                return;
            }

            String resultJson = subWallet.GetTransactionSignedInfo(rawTxJson);
            cc.success(resultJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " tx signed signers");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String rawTxJson
    // return: String resultJson
    public void publishTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String rawTxJson = args.getString(idx++);

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

            String resultJson = subWallet.PublishTransaction(rawTxJson);
            cc.success(resultJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Publish " + formatWalletName(masterWalletID, chainID) + " transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: int start
    // args[3]: int count
    // args[4]: String addressOrTxId
    // return: String txJson
    public void getAllTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);
        String addressOrTxId = args.getString(idx++);

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

            String txJson = subWallet.GetAllTransaction(start, count, addressOrTxId);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " all transaction");
        }
    }

    public void registerWalletListener(JSONArray args, CallbackContext cc) {
        int cordovaHashCode = this.cordova.hashCode();
        subwalletListenerMap.put(cordovaHashCode, cc);
        // Listener, can't call cc.success
    }

    public void removeWalletListener(JSONArray args, CallbackContext cc) {
        int cordovaHashCode = this.cordova.hashCode();
        subwalletListenerMap.remove(cordovaHashCode);
        cc.success("");
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void getLastBlockInfo(JSONArray args, CallbackContext cc) throws JSONException {
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

            String txJson = subWallet.GetLastBlockInfo();
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, "Get " + formatWalletName(masterWalletID, chainID) + " Last Block Info");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[3]: String payloadJson
    // args[4]: String memo
    // args[5]: String fee  [option]
    public void createIdTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
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

            cc.success(idchainSubWallet.CreateIDTransaction(payloadJson, memo, fee));
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

    public void getAllDID(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);

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
            String did = idChainSubWallet.GetAllDID(start, count);

            cc.success(did);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " getAllDID");
        }
    }

    public void getAllCID(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);

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
            String did = idChainSubWallet.GetAllCID(start, count);

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

    public void didSignDigest(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String did = args.getString(idx++);
        String digest = args.getString(idx++);
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
            String result = idChainSubWallet.SignDigest(did, digest, payPassword);
            cc.success(result);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, IDChain) + " didSignDigest");
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

    private EthSidechainSubWallet getEthSidechainSubWallet(String masterWalletID) {
        SubWallet subWallet = getSubWallet(masterWalletID, ETHSC);

        if ((subWallet instanceof EthSidechainSubWallet)) {
            return (EthSidechainSubWallet) subWallet;
        }
        return null;
    }

    // args[0]: String masterWalletID
    // args[1]: String targetAddress
    // args[2]: String amount
    // args[3]: int amountUnit
    public void createTransfer(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String targetAddress = args.getString(idx++);
        String amount = args.getString(idx++);
        int amountUnit = args.getInt(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            EthSidechainSubWallet ethscSubWallet = getEthSidechainSubWallet(masterWalletID);
            if (ethscSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, ETHSC));
                return;
            }
            cc.success(ethscSubWallet.CreateTransfer(targetAddress, amount, amountUnit));
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, ETHSC) + " create transfer");
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
    public void createTransferGeneric(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String targetAddress = args.getString(idx++);
        String amount = args.getString(idx++);
        int amountUnit = args.getInt(idx++);
        String gasPrice = args.getString(idx++);
        int gasPriceUnit = args.getInt(idx++);
        String gasLimit = args.getString(idx++);
        String data = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            EthSidechainSubWallet ethscSubWallet = getEthSidechainSubWallet(masterWalletID);
            if (ethscSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, ETHSC));
                return;
            }
            cc.success(ethscSubWallet.CreateTransferGeneric(targetAddress, amount, amountUnit, gasPrice, gasPriceUnit, gasLimit, data));
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, ETHSC) + " create transfer generic");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String tx: json object, must have ID
    public void deleteTransfer(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String tx = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            EthSidechainSubWallet ethscSubWallet = getEthSidechainSubWallet(masterWalletID);
            if (ethscSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, ETHSC));
                return;
            }
            ethscSubWallet.DeleteTransfer(tx);
            cc.success("DeleteTransfer OK");
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, ETHSC) + " delete transfer");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: int start
    // args[2]: int count
    // args[3]: String txid
    // args[4]: String tokenSymbol
    public void getTokenTransactions(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        int start = args.getInt(idx++);
        int count = args.getInt(idx++);
        String txid = args.getString(idx++);
        String tokenSymbol = args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        try {
            EthSidechainSubWallet ethscSubWallet = getEthSidechainSubWallet(masterWalletID);
            if (ethscSubWallet == null) {
                errorProcess(cc, errCodeInvalidSubWallet, "Get " + formatWalletName(masterWalletID, ETHSC));
                return;
            }
            cc.success(ethscSubWallet.GetTokenTransactions(start, count, txid, tokenSymbol));
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, ETHSC) + " get token transactions");
        }
    }

    // MainchainSubWallet

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String fromAddress
    // args[3]: String lockedAddress
    // args[4]: String amount
    // args[5]: String sideChainAddress
    // args[6]: String memo
    public void createDepositTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String sideChainID = args.getString(idx++);
        String amount = args.getString(idx++);
        String sideChainAddress = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateDepositTransaction(fromAddress, sideChainID, amount,
                    sideChainAddress, memo);

            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create deposit transaction");
        }
    }

    // -- vote

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String fromAddress
    // args[3]: String stake
    // args[4]: String publicKeys JSONArray
    // args[5]: String memo
    public void createVoteProducerTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String stake = args.getString(idx++);
        String publicKeys = args.getString(idx++);
        String memo = args.getString(idx++);
        String invalidCandidates = "[]";// args.getString(idx++);

        if (args.length() != idx) {
            errorProcess(cc, errCodeInvalidArg, idx + " parameters are expected");
            return;
        }

        Log.i(TAG, formatWalletName(masterWalletID, chainID));

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
            String txJson = mainchainSubWallet.CreateVoteProducerTransaction(fromAddress, stake, publicKeys, memo,
                    invalidCandidates);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create vote producer transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String fromAddress
    // args[3]: String votes JSONObject
    // args[4]: String memo
    // args[5]: String invalidCandidates
    public void createVoteCRTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String votes = args.getString(idx++);
        String memo = args.getString(idx++);
        String invalidCandidates = args.getString(idx++);

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
            String txJson = mainchainSubWallet.CreateVoteCRTransaction(fromAddress, votes, memo, invalidCandidates);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create vote CR transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String fromAddress
    // args[3]: String votes JSON object
    // args[4]: String memo
    // args[5]: String invalidCandidates
    public void createVoteCRCProposalTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String votes = args.getString(idx++);
        String memo = args.getString(idx++);
        String invalidCandidates = args.getString(idx++);

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
            String stringJson = mainchainSubWallet.CreateVoteCRCProposalTransaction(fromAddress, votes, memo, invalidCandidates);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " CreateVoteCRCProposalTransaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String fromAddress
    // args[3]: String votes JSON object
    // args[4]: String memo
    // args[5]: String invalidCandidates
    public void createImpeachmentCRCTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String votes = args.getString(idx++);
        String memo = args.getString(idx++);
        String invalidCandidates = args.getString(idx++);

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
            String stringJson = mainchainSubWallet.CreateImpeachmentCRCTransaction(fromAddress, votes, memo, invalidCandidates);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " CreateImpeachmentCRCTransaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    public void getVotedProducerList(JSONArray args, CallbackContext cc) throws JSONException {
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
            String list = mainchainSubWallet.GetVotedProducerList();
            cc.success(list);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get voted producer list");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    public void getVotedCRList(JSONArray args, CallbackContext cc) throws JSONException {
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
            String list = mainchainSubWallet.GetVotedCRList();
            cc.success(list);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get voted CR list");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String type, if the type is empty, a summary of all types of votes will return.
    //              Otherwise, the details of the specified type will return.
    public void getVoteInfo(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String type = args.getString(idx++);

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
            String list = mainchainSubWallet.GetVoteInfo(type);
            cc.success(list);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get vote info list");
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
    // args[2]: String fromAddress
    // args[3]: String payloadJson
    // args[4]: String amount
    // args[5]: String memo
    public void createRegisterProducerTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String amount = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateRegisterProducerTransaction(fromAddress, payloadJson, amount,
                    memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create register producer transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String fromAddress
    // args[3]: String payloadJson
    // args[4]: String memo
    public void createUpdateProducerTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String payloadJson = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateUpdateProducerTransaction(fromAddress, payloadJson, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create update producer transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String fromAddress
    // args[3]: String payloadJson
    // args[4]: String memo
    public void createCancelProducerTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String payloadJson = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateCancelProducerTransaction(fromAddress, payloadJson, memo);
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
        String amount = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateRetrieveDepositTransaction(amount, memo);
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
    // args[1]: String chainID (only main chain ID 'ELA')
    public void getRegisteredProducerInfo(JSONArray args, CallbackContext cc) throws JSONException {
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
            String info = mainchainSubWallet.GetRegisteredProducerInfo();
            cc.success(info);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get registerd producer info");
        }
    }

    // -- CRC

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
    // args[2]: String fromAddress
    // args[3]: String payloadJSON
    // args[4]: String amount
    // args[5]: String memo
    public void createRegisterCRTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String payloadJson = args.getString(idx++);
        String amount = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateRegisterCRTransaction(fromAddress, payloadJson, amount,
                    memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create register CR transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String fromAddress
    // args[3]: String payloadJSON
    // args[4]: String memo
    public void createUpdateCRTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String payloadJson = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateUpdateCRTransaction(fromAddress, payloadJson, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create update CR transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String fromAddress
    // args[3]: String payloadJSON
    // args[4]: String memo
    public void createUnregisterCRTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String payloadJson = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateUnregisterCRTransaction(fromAddress, payloadJson, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create unregister CR transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    // args[2]: String crPublicKey
    // args[3]: String amount
    // args[4]: String memo
    public void createRetrieveCRDepositTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String crPublicKey = args.getString(idx++);
        String amount = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateRetrieveCRDepositTransaction(crPublicKey, amount, memo);
            cc.success(txJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create retrieve CR deposit transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID (only main chain ID 'ELA')
    public void getRegisteredCRInfo(JSONArray args, CallbackContext cc) throws JSONException {
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
            String info = mainchainSubWallet.GetRegisteredCRInfo();

            cc.success(info);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get registerd CR info");
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
        String payload = args.getString(idx++);
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
            String txJson = mainchainSubWallet.CreateCRCouncilMemberClaimNodeTransaction(payload, memo);
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
        String crSignedProposal = args.getString(idx++);
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
            String stringJson = mainchainSubWallet.CreateProposalTransaction(crSignedProposal, memo);
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
        String payload = args.getString(idx++);
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
            String stringJson = mainchainSubWallet.CreateProposalReviewTransaction(payload, memo);
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
        String leaderSignedProposalTracking = args.getString(idx++);
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
            String stringJson = mainchainSubWallet.CreateProposalTrackingTransaction(leaderSignedProposalTracking, memo);
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
        String payload = args.getString(idx++);
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
            String stringJson = mainchainSubWallet.CreateSecretaryGeneralElectionTransaction(payload, memo);
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
        String payload = args.getString(idx++);
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
            String stringJson = mainchainSubWallet.CreateProposalChangeOwnerTransaction(payload, memo);
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
        String payload = args.getString(idx++);
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
            String stringJson = mainchainSubWallet.CreateTerminateProposalTransaction(payload, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createTerminateProposalTransaction");
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
        String payload = args.getString(idx++);
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
            String stringJson = mainchainSubWallet.CreateProposalWithdrawTransaction(payload, memo);
            cc.success(stringJson);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " createProposalWithdrawTransaction");
        }
    }

    // SidechainSubWallet

    // args[0]: String masterWalletID
    // args[1]: String chainID
    // args[2]: String fromAddress
    // args[3]: String amount
    // args[4]: String mainchainAdress
    // args[5]: String memo
    public void createWithdrawTransaction(JSONArray args, CallbackContext cc) throws JSONException {
        int idx = 0;
        String masterWalletID = args.getString(idx++);
        String chainID = args.getString(idx++);
        String fromAddress = args.getString(idx++);
        String amount = args.getString(idx++);
        String mainchainAddress = args.getString(idx++);
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
            String tx = sidechainSubWallet.CreateWithdrawTransaction(fromAddress, amount, mainchainAddress, memo);

            cc.success(tx);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " create withdraw transaction");
        }
    }

    // args[0]: String masterWalletID
    // args[1]: String chainID
    public void getGenesisAddress(JSONArray args, CallbackContext cc) throws JSONException {
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

            if (!(subWallet instanceof SidechainSubWallet)) {
                errorProcess(cc, errCodeSubWalletInstance,
                        formatWalletName(masterWalletID, chainID) + " is not instance of SidechainSubWallet");
                return;
            }

            SidechainSubWallet sidechainSubWallet = (SidechainSubWallet) subWallet;

            String address = sidechainSubWallet.GetGenesisAddress();

            cc.success(address);
        } catch (WalletException e) {
            exceptionProcess(e, cc, formatWalletName(masterWalletID, chainID) + " get genesis address");
        }
    }

    public void getERC20TokenList(JSONArray args, CallbackContext cc) throws JSONException {
        String address = args.getString(0);

        new Thread(() -> {
            try {
                WalletHttprequest walletHttp = new WalletHttprequest(s_ethscGetTokenListUrl);
                String result = walletHttp.getTokenListByAddress(address);
                JSONObject resultObj = new JSONObject(result);
                JSONArray tokenList = resultObj.getJSONArray("result");
                cc.success(tokenList);
            } catch (Exception e) {
                exceptionProcess(e, cc,  " getERC20TokenList");
            }
        }).start();
    }

    public void getBackupInfo(JSONArray args, CallbackContext cc) throws JSONException {
        String masterWalletID = args.getString(0);

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Master wallet "+masterWalletID+" not found");
                return;
            }

            String spvSyncStateFilesPath = getSPVSyncStateFolderPath(masterWalletID);
            JSONObject backupInfo = new JSONObject();

            // ELA mainchain info
            JSONObject elaDatabaseInfo = new JSONObject();
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

            cc.success(backupInfo);
        } catch (WalletException e) {
            exceptionProcess(e, cc, e.GetErrorInfo());
        }
    }

    public void getBackupFile(JSONArray args, CallbackContext cc) throws JSONException {
        String masterWalletID = args.getString(0);
        String fileName = args.getString(1);

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Master wallet "+masterWalletID+" not found");
                return;
            }

            if (!ensureBackupFile(fileName)) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Invalid backup file name "+fileName);
                return;
            }

            try {
                // Open an input stream to read the file
                String spvSyncStateFilesPath = getSPVSyncStateFolderPath(masterWalletID);
                File backupFile = new File(spvSyncStateFilesPath + "/" + fileName);

                BufferedInputStream reader = new BufferedInputStream(new FileInputStream(backupFile));

                String objectId = "" + System.identityHashCode(reader);
                backupFileReaderMap.put(objectId, reader);
                backupFileReaderOffsetsMap.put(objectId, 0); // Current read offset is 0

                JSONObject ret = new JSONObject();
                ret.put("objectId", objectId);
                cc.success(ret);
            } catch (Exception e) {
                errorProcess(cc, errCodeInvalidArg, e.getMessage());
            }
        } catch (WalletException e) {
            exceptionProcess(e, cc, e.GetErrorInfo());
        }
    }

    private void backupFileReader_read(JSONArray args, CallbackContext callbackContext) throws JSONException {
        String readerObjectId = args.getString(0);
        int bytesCount = args.getInt(1);

        try {
            byte[] buffer = new byte[bytesCount];
            InputStream reader = backupFileReaderMap.get(readerObjectId);

            // Resume reading at the previous read offset
            int currentReadOffset = backupFileReaderOffsetsMap.get(readerObjectId);
            //reader.skip(currentReadOffset);
            int readBytes = reader.read(buffer, 0, bytesCount);

            if (readBytes != -1) {
                // Move read offset to the next position
                backupFileReaderOffsetsMap.put(readerObjectId, currentReadOffset + readBytes);
                callbackContext.success(Base64.encodeToString(buffer, 0, readBytes, Base64.NO_WRAP));
            }
            else {
                callbackContext.success((String)null);
            }
        }
        catch (IOException e) {
            callbackContext.error(e.getMessage());
        }
    }

    private void backupFileReader_close(JSONArray args, CallbackContext callbackContext) throws JSONException {
        String readerObjectId = args.getString(0);

        try {
            InputStream reader = backupFileReaderMap.get(readerObjectId);
            reader.close();
            backupFileReaderMap.remove(readerObjectId);
            backupFileReaderOffsetsMap.remove(readerObjectId);
            callbackContext.success();
        }
        catch (IOException e) {
            callbackContext.error(e.getMessage());
        }
    }

    public void restoreBackupFile(JSONArray args, CallbackContext cc) throws JSONException {
        String masterWalletID = args.getString(0);
        String fileName = args.getString(1);

        try {
            MasterWallet masterWallet = getIMasterWallet(masterWalletID);
            if (masterWallet == null) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Master wallet "+masterWalletID+" not found");
                return;
            }

            if (!ensureBackupFile(fileName)) {
                errorProcess(cc, errCodeInvalidMasterWallet, "Invalid backup file name "+fileName);
                return;
            }

            try {
                // Open an output stream to write the file
                String spvSyncStateFilesPath = getSPVSyncStateFolderPath(masterWalletID);
                File backupFile = new File(spvSyncStateFilesPath + "/" + fileName);

                BufferedOutputStream writer = new BufferedOutputStream(new FileOutputStream(backupFile));

                String objectId = "" + System.identityHashCode(writer);
                backupFileWriterMap.put(objectId, writer);

                JSONObject ret = new JSONObject();
                ret.put("objectId", objectId);
                cc.success(ret);
            } catch (Exception e) {
                errorProcess(cc, errCodeInvalidArg, e.getMessage());
            }
        } catch (WalletException e) {
            exceptionProcess(e, cc, e.GetErrorInfo());
        }
    }

    private void backupFileWriter_write(JSONArray args, CallbackContext callbackContext) throws JSONException {
        String writerObjectId = args.getString(0);
        String base64encodedFromUint8Array = args.getString(1);

        try {
            OutputStream writer = backupFileWriterMap.get(writerObjectId);

            // Cordova encodes UInt8Array in TS to base64 encoded in java.
            byte[] data = Base64.decode(base64encodedFromUint8Array, Base64.DEFAULT);
            writer.write(data);

            callbackContext.success();
        }
        catch (IOException e) {
            callbackContext.error(e.getMessage());
        }
    }

    private void backupFileWriter_close(JSONArray args, CallbackContext callbackContext) throws JSONException {
        String writerObjectId = args.getString(0);

        try {
            OutputStream writer = backupFileWriterMap.get(writerObjectId);
            writer.flush();
            writer.close();
            backupFileWriterMap.remove(writerObjectId);
            callbackContext.success();
        }
        catch (IOException e) {
            callbackContext.error(e.getMessage());
        }
    }

    private String getSPVSyncStateFolderPath(String masterWalletID) {
        if ("TestNet".equals(s_netType)) {
            return s_dataRootPath + "TestNet/"+masterWalletID;
        } else {
            return s_dataRootPath + masterWalletID;
        }
    }

    // Returns true if the given filename is a valid wallet file for backup (to make sure we the caller is not
    // trying to access and unauthorized file), false otherwise.
    private boolean ensureBackupFile(String fileName) {
        return fileName.equals("ELA.db") || fileName.equals("IDChain.db");
    }
}
