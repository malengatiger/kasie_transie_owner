import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/big_bag.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/emojis.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/car_list.dart';
import 'package:kasie_transie_library/widgets/counts_widget.dart';
import 'package:kasie_transie_library/widgets/days_drop_down.dart';
import 'package:kasie_transie_library/widgets/language_and_color_chooser.dart';
import 'package:kasie_transie_library/widgets/timer_widget.dart';
import 'package:kasie_transie_route_builder/ui/cellphone_auth_signin.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final mm = '🥬🥬🥬🥬🥬🥬 Dashboard: 😡';

  lib.User? user;
  BigBag? bigBag;
  bool busy = false;
  List<lib.Vehicle> cars = [];
  String? ownerDashboard,
      numberOfCars,
      arrivalsText,
      departuresText,
      heartbeatText,
      daysText,
      loadingOwnerData,
      errorGettingData,
      passengerCounts,
      thisMayTakeMinutes,
      historyCars,
      dispatchesText;

  late StreamSubscription<lib.DispatchRecord> dispatchStreamSub;
  late StreamSubscription<lib.AmbassadorPassengerCount> passengerStreamSub;

  @override
  void initState() {
    super.initState();
    _initialize();
    _checkAuth();
    _setTexts();
  }

  @override
  void dispose() {
    dispatchStreamSub.cancel();
    passengerStreamSub.cancel();
    super.dispose();


  }
  void _initialize() async {
    fcmBloc.subscribeToTopics('OwnerApp');
    dispatchStreamSub =
        fcmBloc.dispatchStream.listen((lib.DispatchRecord dRec) {
      pp('$mm ... fcmBloc.dispatchStream delivered dispatch for: ${dRec.vehicleReg}');
      bigBag!.dispatchRecords.add(dRec);
      totalPassengers += dRec.passengers!;
      if (mounted) {
        setState(() {});
      }
    });
    passengerStreamSub = fcmBloc.passengerCountStream
        .listen((lib.AmbassadorPassengerCount cunt) {
      pp('$mm ... fcmBloc.passengerCountStream delivered count for: ${cunt.vehicleReg}');
      bigBag!.passengerCounts.add(cunt);
      _calculateTotalPassengers();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _checkAuth() async {
    user = await prefs.getUser();
    if (user == null) {
      _navigateToSignIn();
    } else {
      _getData(false);
    }
  }

  void _setTexts() async {
    var c = await prefs.getColorAndLocale();
    numberOfCars = await translator.translate('numberOfCars', c.locale);
    arrivalsText = await translator.translate('arrivals', c.locale);
    departuresText = await translator.translate('departures', c.locale);
    heartbeatText = await translator.translate('heartbeats', c.locale);
    dispatchesText = await translator.translate('dispatches', c.locale);
    ownerDashboard = await translator.translate('ownerDash', c.locale);
    daysText = await translator.translate('days', c.locale);
    historyCars = await translator.translate('historyCars', c.locale);
    passengerCounts = await translator.translate('passengersIn', c.locale);
    loadingOwnerData = await translator.translate('loadingOwnerData', c.locale);
    thisMayTakeMinutes =
        await translator.translate('thisMayTakeMinutes', c.locale);
    errorGettingData = await translator.translate('errorGettingData', c.locale);

    setState(() {});
  }

  void _navigateToSignIn() async {
    pp('$mm ... _navigateToSignIn ...');
    var res = await navigateWithScale(
        CellPhoneAuthSignin(dataApiDog: dataApiDog), context);
    pp('\n\nmm .... back from sign in : $res');
    _getData(false);
  }

  int totalPassengers = 0;

  Future _refreshBag() async {
    final date = DateTime.now().toUtc().subtract(Duration(days: days));
    setState(() {
      busy = true;
    });
    try {
      bigBag =
          await listApiDog.getOwnersBag(user!.userId!, date.toIso8601String());

      pp('$mm _refreshBag: ${E.appleRed} '
          '\n🔴 cars: ${cars.length} '
          '\n🔴 vehicleHeartbeats: ${bigBag?.vehicleHeartbeats.length} '
          '\n🔴 vehicleArrivals: ${bigBag?.vehicleArrivals.length} '
          '\n🔴 dispatchRecords: ${bigBag?.dispatchRecords.length} '
          '\n🔴 passengerCounts: ${bigBag?.passengerCounts.length} '
          '\n🔴 vehicleDepartures: ${bigBag?.vehicleDepartures.length}');

      _calculateTotalPassengers();
    } catch (e) {
      pp(e);
      if (mounted) {
        showSnackBar(
            message: errorGettingData == null
                ? 'Error getting data'
                : errorGettingData!,
            context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  Future _getData(bool refresh) async {
    pp('$mm .... getting owner data ....');
    //todo - add feature to pick start date
    try {
      setState(() {
        busy = true;
      });
      user = await prefs.getUser();
      if (user == null) {
        throw Exception('Fuck!! No User');
      }
      if (user!.userId == null) {
        throw Exception('Fuck!! No User id! wtf?');
      }
      final date = DateTime.now().toUtc().subtract(Duration(days: days));
      cars = await listApiDog.getOwnerVehicles(user!.userId!, refresh);
      bigBag =
          await listApiDog.getOwnersBag(user!.userId!, date.toIso8601String());

      pp('$mm _getData: ${E.appleRed} '
          '\n🔴 cars: ${cars.length} '
          '\n🔴 vehicleHeartbeats: ${bigBag?.vehicleHeartbeats.length} '
          '\n🔴 vehicleArrivals: ${bigBag?.vehicleArrivals.length} '
          '\n🔴 dispatchRecords: ${bigBag?.dispatchRecords.length} '
          '\n🔴 passengerCounts: ${bigBag?.passengerCounts.length} '
          '\n🔴 vehicleDepartures: ${bigBag?.vehicleDepartures.length}');

      _calculateTotalPassengers();
    } catch (e) {
      pp(e);
    }
    setState(() {
      busy = false;
    });
  }

  void _calculateTotalPassengers() {
    totalPassengers = 0;
    for (var value in bigBag!.passengerCounts) {
      totalPassengers += value.passengersIn!;
    }
  }

  Future<void> _navigateToCarList() async {
    var car = await navigateWithScale(
        CarList(
          ownerId: user!.userId,
        ),
        context);
    pp('$mm .... back from car list');
  }

  void _navigateToColor() async {
    pp('$mm navigate to color ...');
    await navigateWithScale(const LanguageAndColorChooser(), context);
    _setTexts();
  }

  int days = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          ownerDashboard == null ? 'Owner Dashboard' : ownerDashboard!,
          style: myTextStyleMediumLarge(context, 24),
        ),
        actions: [
          IconButton(
              onPressed: () {
                _navigateToColor();
              },
              icon: Icon(
                Icons.color_lens,
                color: Theme.of(context).primaryColor,
              )),
          IconButton(
              onPressed: () {
                _refreshBag();
              },
              icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor)),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Card(
              shape: getRoundedBorder(radius: 16),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _navigateToCarList();
                      },
                      child: Card(
                        shape: getRoundedBorder(radius: 16),
                        elevation: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 64,
                              ),
                              Text(numberOfCars == null
                                  ? 'Number of Cars'
                                  : numberOfCars!),
                              const SizedBox(
                                width: 12,
                              ),
                              Text(
                                '${cars.length}',
                                style: myTextStyleMediumLargeWithColor(context,
                                    Theme.of(context).primaryColor, 36),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    user == null
                        ? const Text('....')
                        : Text(
                            user!.name,
                            style: myTextStyleSmall(context),
                          ),
                    const SizedBox(
                      height: 64,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          historyCars == null
                              ? 'History for all cars'
                              : historyCars!,
                          style: myTextStyleMedium(context),
                        ),
                        const SizedBox(
                          width: 20,
                        ),
                        Text(
                          '$days',
                          style: myTextStyleMediumLargeWithColor(
                              context, Theme.of(context).primaryColor, 24),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        DaysDropDown(
                            onDaysPicked: (d) {
                              setState(() {
                                days = d;
                              });
                              _refreshBag();
                            },
                            hint: daysText == null ? 'Days' : daysText!),
                      ],
                    ),
                    const SizedBox(
                      height: 48,
                    ),
                    bigBag == null
                        ? const SizedBox()
                        : Expanded(
                            child: CountsGridWidget(
                              passengerCounts: totalPassengers,
                              arrivalsText: arrivalsText!,
                              departuresText: departuresText!,
                              dispatchesText: dispatchesText!,
                              heartbeatText: heartbeatText!,
                              arrivals: bigBag!.vehicleArrivals.length,
                              departures: bigBag!.vehicleDepartures.length,
                              heartbeats: bigBag!.vehicleHeartbeats.length,
                              dispatches: bigBag!.dispatchRecords.length,
                              passengerCountsText: passengerCounts!,
                            ),
                          )
                  ],
                ),
              ),
            ),
          ),
          busy
              ? Positioned(
                  left: 24,
                  right: 24,
                  bottom: 140,
                  top: 140,
                  child: TimerWidget(
                    title: loadingOwnerData == null
                        ? 'Loading Owner data'
                        : loadingOwnerData!,
                    subTitle: thisMayTakeMinutes == null
                        ? 'This may take a few minutes'
                        : thisMayTakeMinutes!,
                  ))
              : const SizedBox(),
        ],
      ),
    ));
  }
}
