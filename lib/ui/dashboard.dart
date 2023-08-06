import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/big_bag.dart';
import 'package:kasie_transie_library/data/color_and_locale.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/maps/association_route_maps.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/emojis.dart';
import 'package:kasie_transie_library/utils/error_handler.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/initializer.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/auth/cell_auth_signin.dart';
import 'package:kasie_transie_library/widgets/auth/damn_email_link.dart';
import 'package:kasie_transie_library/widgets/counts_widget.dart';
import 'package:kasie_transie_library/widgets/days_drop_down.dart';
import 'package:kasie_transie_library/widgets/language_and_color_chooser.dart';
import 'package:kasie_transie_library/widgets/scanners/scan_vehicle_for_owner.dart';
import 'package:kasie_transie_library/widgets/timer_widget.dart';
import 'package:kasie_transie_library/widgets/vehicle_widgets/car_list.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final mm = '🥬🥬🥬🥬🥬🥬Owner Dashboard: 😡';

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
  late StreamSubscription<lib.VehicleArrival> arrivalStreamSub;
  late StreamSubscription<lib.VehicleDeparture> departureStreamSub;
  late StreamSubscription<lib.LocationResponse> locResponseStreamSub;



  String notRegistered =
      'You are not registered yet. Please call your administrator';
  String emailNotFound = 'emailNotFound';
  String welcome = 'Welcome';
  String firstTime =
      'This is the first time that you have opened the app and you '
      'need to sign in to your Taxi Association.';
  String changeLanguage = 'Change Language or Color';
  String startEmailLinkSignin = 'Start Email Link Sign In';
  String signInWithPhone = 'Start Phone Sign In';
  bool _showVerifier = true;
  bool _showDashboard = true;

  late ColorAndLocale colorAndLocale;

  @override
  void initState() {
    super.initState();
    _initialize();
    _checkAuth();
  }

  @override
  void dispose() {
    dispatchStreamSub.cancel();
    passengerStreamSub.cancel();
    super.dispose();
  }

  void _initialize() async {

    fcmBloc.subscribeForOwnerMarshalOfficialAmbassador('OwnerApp');
    departureStreamSub =
        fcmBloc.vehicleDepartureStream.listen((lib.VehicleDeparture departure) {
          pp('$mm ... fcmBloc.vehicleDepartureStream delivered vehicle departure for: ${departure.vehicleReg}');
          if (mounted) {
            setState(() {});
          }
        });
    locResponseStreamSub =
        fcmBloc.locationResponseStream.listen((lib.LocationResponse locationResponse) {
          pp('$mm ... fcmBloc.locationResponseStream delivered loc response for: ${locationResponse.vehicleReg}');
          if (mounted) {
            setState(() {});
          }
        });
    arrivalStreamSub =
        fcmBloc.vehicleArrivalStream.listen((lib.VehicleArrival vehicleArrival) {
          pp('$mm ... fcmBloc.dispatchStream delivered dispatch for: ${vehicleArrival.vehicleReg}');
          bigBag!.vehicleArrivals.add(vehicleArrival);
          if (mounted) {
            setState(() {});
          }
        });
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
    await _setTexts();
    user = await prefs.getUser();
    if (user == null) {
      setState(() {
        _showVerifier = true;
        _showDashboard = false;
      });
    } else {
      setState(() {
        _showVerifier = false;
        _showDashboard = true;
      });
      _getData(false);
    }
  }

  Future _setTexts() async {
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
    emailNotFound =
        await translator.translate('emailNotFound', c.locale);
    notRegistered =
        await translator.translate('notRegistered', c.locale);
    firstTime = await translator.translate('firstTime', c.locale);
    changeLanguage =
        await translator.translate('changeLanguage', c.locale);
    welcome = await translator.translate('welcome', c.locale);
    startEmailLinkSignin =
        await translator.translate('signInWithEmail', c.locale);
    signInWithPhone =
        await translator.translate('signInWithPhone', c.locale);
    setState(() {});
  }

  Future _navigateToColor() async {
    pp('$mm _navigateToColor ......');
    await navigateWithScale( LanguageAndColorChooser(onLanguageChosen: (){},), context);
    colorAndLocale = await prefs.getColorAndLocale();
    await _setTexts();
  }

  Future<void> _navigateToEmailAuth() async {
    var res = await navigateWithScale( DamnEmailLink(onLanguageChosen: (){},), context);
    pp('\n\n$mm ................ back from sign in: $res');
    user = await prefs.getUser();
    _getData(false);
  }

  Future<void> _navigateToMaps() async {
    await navigateWithScale(const AssociationRouteMaps(), context);
    user = await prefs.getUser();
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
          duration: const Duration(seconds: 10),
            backgroundColor: Colors.redAccent,
            textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

      pp('$mm _getData .. owner bag: ${E.appleRed} '
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
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.red,
            textStyle: const TextStyle(color: Colors.white),
            message: 'Error getting data: $e', context: context);
      }
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
    await navigateWithScale(
        CarList(
          ownerId: user!.userId,
        ),
        context);
    pp('$mm .... back from car list');
  }

  Future<void> _navigateToScanner() async {
    await navigateWithScale(
        const ScanVehicleForOwner(),
        context);
    pp('$mm .... back from car update');
  }

  int days = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          ownerDashboard == null ? 'Owner Dashboard' : ownerDashboard!,
          style: myTextStyleMediumLarge(context, 18),
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
                _navigateToMaps();
              },
              icon: Icon(
                Icons.map,
                color: Theme.of(context).primaryColor,
              )),
          IconButton(
              onPressed: () {
                _navigateToScanner();
              },
              icon: Icon(Icons.airport_shuttle, color: Theme.of(context).primaryColor)),
        ],
      ),
      body: Stack(
        children: [
          _showVerifier? CustomPhoneVerification(onUserAuthenticated: (user){
            setState(() {
              _showDashboard = true;
              _showVerifier = false;
            });
            _getData(false);
          }, onError: (){}, onCancel: (){}, onLanguageChosen: (){
            _setTexts();
          },): const SizedBox(),

          _showDashboard? Padding(
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
                                style: myTextStyleMediumLargeWithColor(
                                    context,
                                    Theme.of(context).primaryColor,
                                    36),
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
                          style: myTextStyleMediumLargeWithColor(context,
                              Theme.of(context).primaryColor, 24),
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
                        departures:
                        bigBag!.vehicleDepartures.length,
                        heartbeats:
                        bigBag!.vehicleHeartbeats.length,
                        dispatches: bigBag!.dispatchRecords.length,
                        passengerCountsText: passengerCounts!,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ): const SizedBox(),

          busy
              ? Positioned(
                  left: 12,
                  right: 12,
                  bottom: 60,
                  top: 60,
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

class SignInLanding extends StatelessWidget {
  const SignInLanding(
      {Key? key,
      required this.welcome,
      required this.firstTime,
      required this.changeLanguage,
      required this.signInWithPhone,
      required this.startEmailLinkSignin,
      required this.onNavigateToEmailAuth,
      required this.onNavigateToPhoneAuth,
      required this.onNavigateToColor})
      : super(key: key);

  final String welcome,
      firstTime,
      changeLanguage,
      signInWithPhone,
      startEmailLinkSignin;
  final Function onNavigateToEmailAuth,
      onNavigateToPhoneAuth,
      onNavigateToColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
            width: 40,
            height: 40,
            child: Image.asset(
              'assets/gio.png',
            )),
        const SizedBox(
          height: 12,
        ),
        Text(
          welcome,
          style: myTextStyleMediumLargeWithColor(
              context, Theme.of(context).primaryColorLight, 40),
        ),
        const SizedBox(
          height: 32,
        ),
        Text(
          firstTime,
          style: myTextStyleMedium(context),
        ),
        const SizedBox(
          height: 24,
        ),
        SizedBox(
          width: 300,
          child: ElevatedButton(
            style: ButtonStyle(
              elevation: const MaterialStatePropertyAll(4.0),
              backgroundColor:
                  MaterialStatePropertyAll(Theme.of(context).primaryColorLight),
            ),
            onPressed: () {
              onNavigateToColor();
            },
            // icon: const Icon(Icons.language),

            child: Text(
              changeLanguage,
              style: myTextStyleSmallBlack(context),
            ),
          ),
        ),
        const SizedBox(
          height: 160,
        ),
        SizedBox(
          width: 340,
          child: ElevatedButton.icon(
              onPressed: () {
                onNavigateToPhoneAuth();
              },
              style: ButtonStyle(
                elevation: const MaterialStatePropertyAll(8.0),
                backgroundColor:
                    MaterialStatePropertyAll(Theme.of(context).primaryColor),
              ),
              label: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  signInWithPhone,
                  style: myTextStyleSmallBlack(context),
                ),
              ),
              icon: const Icon(Icons.phone)),
        ),
        const SizedBox(
          height: 24,
        ),
        Container(
          color: Theme.of(context).primaryColorLight,
          width: 160,
          height: 2,
        ),
        const SizedBox(
          height: 24,
        ),
        SizedBox(
          width: 340,
          child: ElevatedButton.icon(
              onPressed: () {
                onNavigateToEmailAuth();
              },
              style: ButtonStyle(
                elevation: const MaterialStatePropertyAll(8.0),
                backgroundColor:
                    MaterialStatePropertyAll(Theme.of(context).primaryColor),
              ),
              icon: const Icon(Icons.email),
              label: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  startEmailLinkSignin,
                  style: myTextStyleSmallBlack(context),
                ),
              )),
        ),
        const SizedBox(
          height: 24,
        ),
      ],
    );
  }
}
