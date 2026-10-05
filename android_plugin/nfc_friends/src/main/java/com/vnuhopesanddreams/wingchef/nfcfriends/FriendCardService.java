package com.vnuhopesanddreams.wingchef.nfcfriends;

import android.nfc.cardemulation.HostApduService;
import android.os.Bundle;

import java.nio.charset.StandardCharsets;

/**
 * Lets this phone act as an NFC "card" for the other phone to read. Only answers while
 * the bump screen is open (Exchange.myCode set); otherwise it stays quiet.
 */
public class FriendCardService extends HostApduService {
    @Override
    public byte[] processCommandApdu(byte[] apdu, Bundle extras) {
        String mine = Exchange.myCode;
        if (mine == null) {
            return Exchange.NOT_READY;
        }
        if (Exchange.isSelect(apdu)) {
            return Exchange.OK;
        }
        if (Exchange.isExchange(apdu)) {
            Exchange.linked(Exchange.codeIn(apdu));
            return Exchange.withOk(mine.getBytes(StandardCharsets.UTF_8));
        }
        return Exchange.UNKNOWN;
    }

    @Override
    public void onDeactivated(int reason) {
    }
}
