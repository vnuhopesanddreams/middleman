package com.vnuhopesanddreams.wingchef.nfcfriends;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.IsoDep;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;

import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Random;
import java.util.Set;

/**
 * Bumping two phones together to swap friend codes, for Godot (as the NfcFriends
 * singleton).
 *
 * A phone can't read NFC and act as an NFC card at the same moment, so while linking
 * each phone flips between the two at random intervals. Held together, sooner or later
 * one is reading while the other is the card, and the read swaps both codes
 * (see Exchange). Both phones then emit friend_linked with the other's code.
 */
public class NfcFriendsPlugin extends GodotPlugin implements NfcAdapter.ReaderCallback, Exchange.Listener {
    private static final String SIGNAL_LINKED = "friend_linked";
    /** How long each reader/card turn lasts, in milliseconds: this plus up to RANDOM_MS. */
    private static final int MIN_TURN_MS = 250;
    private static final int RANDOM_MS = 650;
    private static final int READ_TIMEOUT_MS = 1000;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Random random = new Random();
    private boolean linking;
    private boolean reading;
    private boolean resumed = true;

    private final Runnable switchTurn = new Runnable() {
        @Override
        public void run() {
            if (!linking) {
                return;
            }
            setReading(!reading && resumed);
            handler.postDelayed(this, MIN_TURN_MS + random.nextInt(RANDOM_MS));
        }
    };

    public NfcFriendsPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "NfcFriends";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo(SIGNAL_LINKED, String.class));
        return signals;
    }

    /** Whether this phone can bump at all (has NFC and can act as a card). */
    @UsedByGodot
    public boolean hasNfc() {
        Activity activity = getActivity();
        return adapter() != null && activity != null
                && activity.getPackageManager().hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION);
    }

    /** Whether NFC is switched on in the phone's settings. */
    @UsedByGodot
    public boolean isNfcOn() {
        NfcAdapter nfc = adapter();
        return nfc != null && nfc.isEnabled();
    }

    @UsedByGodot
    public void openNfcSettings() {
        Activity activity = getActivity();
        if (activity != null) {
            activity.startActivity(new Intent(Settings.ACTION_NFC_SETTINGS));
        }
    }

    /** Starts listening for a bump, offering `myCode` to whoever is bumped. */
    @UsedByGodot
    public void startLinking(String myCode) {
        runOnUiThread(() -> {
            Exchange.myCode = myCode;
            Exchange.listener = this;
            if (!linking) {
                linking = true;
                handler.post(switchTurn);
            }
        });
    }

    @UsedByGodot
    public void stopLinking() {
        runOnUiThread(this::stop);
    }

    private void stop() {
        linking = false;
        Exchange.myCode = null;
        Exchange.listener = null;
        handler.removeCallbacks(switchTurn);
        setReading(false);
    }

    private NfcAdapter adapter() {
        Activity activity = getActivity();
        return activity == null ? null : NfcAdapter.getDefaultAdapter(activity);
    }

    private void setReading(boolean on) {
        Activity activity = getActivity();
        NfcAdapter nfc = adapter();
        if (activity == null || nfc == null) {
            reading = false;
            return;
        }
        if (on) {
            int flags = NfcAdapter.FLAG_READER_NFC_A | NfcAdapter.FLAG_READER_NFC_B
                    | NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK | NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS;
            nfc.enableReaderMode(activity, this, flags, null);
        } else if (reading) {
            nfc.disableReaderMode(activity);
        }
        reading = on;
    }

    /** Reading the other phone (runs on a background thread). */
    @Override
    public void onTagDiscovered(Tag tag) {
        String mine = Exchange.myCode;
        IsoDep card = IsoDep.get(tag);
        if (mine == null || card == null) {
            return;
        }
        try {
            card.connect();
            card.setTimeout(READ_TIMEOUT_MS);
            if (!Exchange.endsOk(card.transceive(Exchange.selectCommand()))) {
                return;
            }
            byte[] response = card.transceive(Exchange.exchangeCommand(mine));
            if (Exchange.endsOk(response) && response.length > 2) {
                onLinked(new String(response, 0, response.length - 2, StandardCharsets.UTF_8));
            }
        } catch (IOException ignored) {
            // Moved apart mid-read; they'll try again on the next turn.
        } finally {
            try {
                card.close();
            } catch (IOException ignored) {
            }
        }
    }

    /** A bump went through, from either side (reading, or being read as the card). */
    @Override
    public void onLinked(String friendCode) {
        handler.post(() -> {
            if (!linking) {
                return;
            }
            stop();
            emitSignal(SIGNAL_LINKED, friendCode);
        });
    }

    @Override
    public void onMainPause() {
        resumed = false;
        setReading(false);
    }

    @Override
    public void onMainResume() {
        resumed = true;
    }
}
