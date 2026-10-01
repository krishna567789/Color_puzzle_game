/// The two documents the stores make us show, kept in the app rather than
/// behind a link: a player who opens them in a plane or on a device with no
/// network still gets an answer, and the text cannot drift out of sync with
/// what the code actually does.
///
/// Before publishing, re-read each list against the SDKs in `pubspec.yaml` -
/// the moment the game collects something new, this copy becomes a lie.
class LegalSection {
  final String heading;
  final List<String> paragraphs;

  const LegalSection(this.heading, this.paragraphs);
}

class LegalDoc {
  final String title;
  final List<LegalSection> sections;

  const LegalDoc({required this.title, required this.sections});
}

class LegalDocs {
  static const LegalDoc privacy = LegalDoc(
    title: 'Privacy Policy',
    sections: [
      LegalSection(
        'What we collect',
        [
          'Your progress - the levels you have unlocked, stars, coins, gems, '
          'items, streaks and your settings - is written to this device only. '
          'We run no account system and no server of our own, so none of it '
          'reaches us unless you put it there yourself.',
        ],
      ),
      LegalSection(
        'Ads',
        [
          'The free version shows adverts served by Google AdMob. AdMob uses '
          'the device\'s advertising identifier to choose and measure ads, and '
          'may use it to personalise them across other apps. Purchasing the '
          'ad removal stops every ad we serve.',
        ],
      ),
      LegalSection(
        'Usage statistics',
        [
          'We collect anonymous app usage events through Firebase Analytics - '
          'for example that a level was finished, an ad was shown, or a store '
          'item was bought - together with the app version and device model. '
          'There is no name, no contact detail, no message content and no '
          'location in any of it, and the numbers are read in aggregate to '
          'decide what to fix next.',
        ],
      ),
      LegalSection(
        'Google Play Games',
        [
          'Play Games is optional and off until you connect it from Settings. '
          'If you do, we read your player display name and avatar so the '
          'leaderboard can show you, we store your achievements and highest '
          'level there, and we keep one copy of your save so you can carry it '
          'to another phone. Disconnecting or deleting your Play Games data '
          'removes all of it.',
        ],
      ),
      LegalSection(
        'Purchases',
        [
          'Payments are taken by Google Play or the App Store. The game never '
          'sees or stores your card number, and your receipt stays with the '
          'store.',
        ],
      ),
      LegalSection(
        'What we never touch',
        [
          'Camera, microphone, contacts, messages, files and location. The app '
          'asks for none of them, and the game is playable with no permission '
          'granted at all.',
        ],
      ),
      LegalSection(
        'Children',
        [
          'This game is not directed at children under 13, we do not knowingly '
          'collect personal information from them, and ads shown here are not '
          'configured for a child-directed audience.',
        ],
      ),
      LegalSection(
        'Deleting your data',
        [
          'Settings > Delete my progress wipes every level, star, balance, '
          'owned item, streak and preference on this device immediately, and '
          'overwrites the copy kept in Google Play Games if you are connected. '
          'Anything held by AdMob or Firebase is under those companies\' own '
          'controls, and resetting the device or clearing the app removes the '
          'rest. Purchases you paid for are kept - a licence you bought is '
          'yours, not progress we can take back.',
        ],
      ),
      LegalSection(
        'Changes',
        [
          'If this policy changes, the new text ships with the next update of '
          'the game, and the date at the bottom of this page moves with it.',
        ],
      ),
    ],
  );

  static const LegalDoc terms = LegalDoc(
    title: 'Terms of Use',
    sections: [
      LegalSection(
        'Your licence',
        [
          'You may install and play this game on the devices you own, for '
          'personal, non-commercial use. That licence is not a sale: you may '
          'not resell, redistribute, reverse-engineer or repackage the app or '
          'its artwork, and you may not put it behind your own paywall.',
        ],
      ),
      LegalSection(
        'Game currency and purchases',
        [
          'Coins, gems and items have value only inside this game. They come '
          'from playing, from adverts you choose to watch, or from a store '
          'purchase. They are not refundable by us, carry no cash value, and '
          'are not transferable between accounts or people; refunds go through '
          'Google Play or the App Store, who took the payment.',
        ],
      ),
      LegalSection(
        'Playing fair',
        [
          'Modifying the game to hand yourself coins, stars or leaderboard '
          'scores you did not earn, or using it to probe, overload or damage '
          'our services, breaks these terms and can cost you that leaderboard '
          'place.',
        ],
      ),
      LegalSection(
        'Your progress',
        [
          'Progress lives on your device, with an optional copy in Google Play '
          'Games. Losing a phone, uninstalling the game or deleting your data '
          'ends it; keeping Play Games connected is how you carry a save '
          'between devices. We are not able to restore a progress a player has '
          'deleted on purpose.',
        ],
      ),
      LegalSection(
        'Updates',
        [
          'Levels, prices, rewards and adverts change between releases. We may '
          'retire a feature, and an update may require a newer operating '
          'system.',
        ],
      ),
      LegalSection(
        'As it is',
        [
          'The game is provided as it is, without a warranty that it will '
          'suit your needs or run without interruption. To the fullest extent '
          'the law allows, we are not liable for indirect or incidental loss '
          'arising from playing it.',
        ],
      ),
    ],
  );

  /// Both documents are one screen with different content, so nothing can make
  /// them disagree about their own header block.
  static const String _footer =
      'Last updated 30 September 2026. This page is part of the app itself, so '
      'it travels with the version you installed.';

  static String get footer => _footer;
}
