package com.vnuhopesanddreams.wingchef.nfcfriends;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/**
 * The little conversation two phones have when they're held together, shared by the
 * reader side (NfcFriendsPlugin) and the card side (FriendCardService).
 *
 * The reader selects our made-up application id, then sends an EXCHANGE command
 * carrying its friend code; the card answers with its own. One tap, both phones
 * learn each other's code.
 */
final class Exchange {
    /** F0 (a proprietary id) followed by "WINGCHF". Must match res/xml/apduservice.xml. */
    static final byte[] AID = {(byte) 0xF0, 0x57, 0x49, 0x4E, 0x47, 0x43, 0x48, 0x46};

    static final byte CLA_PROPRIETARY = (byte) 0x80;
    static final byte INS_EXCHANGE = 0x10;

    static final byte[] OK = {(byte) 0x90, 0x00};
    static final byte[] NOT_READY = {0x69, (byte) 0x85};
    static final byte[] UNKNOWN = {0x6A, (byte) 0x82};

    /** Told when a bump went through, with the other phone's friend code. */
    interface Listener {
        void onLinked(String friendCode);
    }

    /** This phone's friend code while the bump screen is open; null otherwise. */
    static volatile String myCode;
    static volatile Listener listener;

    private Exchange() {}

    static byte[] selectCommand() {
        byte[] command = new byte[5 + AID.length + 1];
        command[0] = 0x00;
        command[1] = (byte) 0xA4;
        command[2] = 0x04;
        command[3] = 0x00;
        command[4] = (byte) AID.length;
        System.arraycopy(AID, 0, command, 5, AID.length);
        command[command.length - 1] = 0x00;
        return command;
    }

    static byte[] exchangeCommand(String code) {
        byte[] data = code.getBytes(StandardCharsets.UTF_8);
        byte[] command = new byte[5 + data.length + 1];
        command[0] = CLA_PROPRIETARY;
        command[1] = INS_EXCHANGE;
        command[4] = (byte) data.length;
        System.arraycopy(data, 0, command, 5, data.length);
        command[command.length - 1] = 0x00;
        return command;
    }

    static boolean isSelect(byte[] apdu) {
        if (apdu.length < 5 + AID.length || apdu[0] != 0x00 || apdu[1] != (byte) 0xA4 || apdu[2] != 0x04) {
            return false;
        }
        return (apdu[4] & 0xFF) == AID.length && Arrays.equals(Arrays.copyOfRange(apdu, 5, 5 + AID.length), AID);
    }

    static boolean isExchange(byte[] apdu) {
        return apdu.length >= 5 && apdu[0] == CLA_PROPRIETARY && apdu[1] == INS_EXCHANGE
                && apdu.length >= 5 + (apdu[4] & 0xFF);
    }

    /** The friend code inside an EXCHANGE command. */
    static String codeIn(byte[] exchange) {
        return new String(exchange, 5, exchange[4] & 0xFF, StandardCharsets.UTF_8);
    }

    static boolean endsOk(byte[] response) {
        int n = response.length;
        return n >= 2 && response[n - 2] == OK[0] && response[n - 1] == OK[1];
    }

    static byte[] withOk(byte[] data) {
        byte[] response = Arrays.copyOf(data, data.length + 2);
        response[data.length] = OK[0];
        response[data.length + 1] = OK[1];
        return response;
    }

    static void linked(String friendCode) {
        Listener current = listener;
        if (current != null) {
            current.onLinked(friendCode);
        }
    }
}
