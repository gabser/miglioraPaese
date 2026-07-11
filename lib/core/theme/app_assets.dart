import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';

class AppAssets {
  const AppAssets._();

  static const logo = 'assets/brand/logo.svg';
  static const appIcon = 'assets/brand/app-icon-192.png';
  static const cityMap = 'assets/illustrations/city-map.svg';
  static const tutorialComune = 'assets/illustrations/tut-1-comune.svg';
  static const tutorialPrevedi = 'assets/illustrations/tut-2-prevedi.svg';
  static const tutorialEsito = 'assets/illustrations/tut-3-esito.svg';
  static const tutorialReputazione =
      'assets/illustrations/tut-4-reputazione.svg';

  static const navHome = 'assets/icons/nav-home.svg';
  static const navPlay = 'assets/icons/nav-play.svg';
  static const navBoard = 'assets/icons/nav-board.svg';
  static const navLeaderboard = 'assets/icons/nav-leaderboard.svg';
  static const navProfile = 'assets/icons/nav-profile.svg';
  static const uiCheck = 'assets/icons/ui-check.svg';
  static const uiSpark = 'assets/icons/ui-spark.svg';
  static const uiTarget = 'assets/icons/ui-target.svg';
  static const uiVote = 'assets/icons/ui-vote.svg';

  static String forProblemKey(ProblemKey key) {
    return switch (key) {
      ProblemKey.lighting => 'assets/icons/cat-illuminazione.svg',
      ProblemKey.potholes => 'assets/icons/cat-buche.svg',
      ProblemKey.waste => 'assets/icons/cat-rifiuti.svg',
      ProblemKey.cleanliness => 'assets/icons/cat-pulizia.svg',
      ProblemKey.green => 'assets/icons/cat-verde.svg',
      ProblemKey.signage => 'assets/icons/cat-segnaletica.svg',
      ProblemKey.transport => 'assets/icons/cat-trasporti.svg',
      ProblemKey.parking => 'assets/icons/cat-parcheggi.svg',
      ProblemKey.decor => 'assets/icons/cat-decoro.svg',
      ProblemKey.noise => 'assets/icons/cat-rumore.svg',
      ProblemKey.safety => 'assets/icons/cat-sicurezza.svg',
      ProblemKey.construction => 'assets/icons/cat-cantieri.svg',
      ProblemKey.queues => 'assets/icons/cat-code.svg',
    };
  }

  static String forPredictionChoice(PredictionChoice choice) {
    return switch (choice) {
      PredictionChoice.improve => 'assets/icons/trend-up.svg',
      PredictionChoice.stable => 'assets/icons/trend-flat.svg',
      PredictionChoice.worsen => 'assets/icons/trend-down.svg',
    };
  }
}

class AppSvg extends StatelessWidget {
  const AppSvg(this.asset, {super.key, this.size = 24, this.color});

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
