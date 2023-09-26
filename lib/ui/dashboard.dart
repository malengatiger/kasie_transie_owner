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
import 'package:kasie_transie_library/utils/functions.dart';
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
import 'package:kasie_transie_library/widgets/vehicle_widgets/route_assigner.dart';
import 'package:permission_handler/permission_handler.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({Key? key}) : super(key: key);

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final mm = '🥬🥬🥬🥬🥬🥬 Owner Dashboard: 😡';

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
  late StreamSubscription<List<lib.Vehicle>> vehiclesStreamSub;

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
    pp('$mm ... listen to streams ........ ');
    vehiclesStreamSub =
        listApiDog.vehiclesStream.listen((List<lib.Vehicle> list) {
      pp('$mm ... listApiDog.vehiclesStream delivered vehicles for: ${list.length}');
      cars = list;
      // _refreshBag();
      if (mounted) {
        setState(() {});
      }
    });
    departureStreamSub =
        fcmBloc.vehicleDepartureStream.listen((lib.VehicleDeparture departure) {
      pp('$mm ... fcmBloc.vehicleDepartureStream delivered vehicle departure for: ${departure.vehicleReg}');
      if (mounted) {
        setState(() {});
      }
    });
    locResponseStreamSub = fcmBloc.locationResponseStream
        .listen((lib.LocationResponse locationResponse) {
      pp('$mm ... fcmBloc.locationResponseStream delivered loc response for: ${locationResponse.vehicleReg}');
      if (mounted) {
        setState(() {});
      }
    });
    arrivalStreamSub = fcmBloc.vehicleArrivalStream
        .listen((lib.VehicleArrival vehicleArrival) {
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
      _navigateToPhoneAuth();
    } else {
      _getPermission();
      _getData(false);
    }
  }

  void _getPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.storage,
      Permission.camera,
    ].request();
    pp('$mm PermissionStatus: statuses: $statuses');
  }

  Future _setTexts() async {
    var c = await prefs.getColorAndLocale();
    numberOfCars = await translator.translate('numberOfCars', c.locale);
    arrivalsText = await translator.translate('arrivals', c.locale);
    departuresText = await translator.translate('departures', c.locale);
    heartbeatText = await translator.translate('heartbeats', c.locale);
    dispatchesText = await translator.translate('dispatches', c.locale);
    ownerDashboard = await translator.translate('dashboard', c.locale);
    daysText = await translator.translate('days', c.locale);
    historyCars = await translator.translate('historyCars', c.locale);
    passengerCounts = await translator.translate('passengersIn', c.locale);
    loadingOwnerData = await translator.translate('loadingOwnerData', c.locale);
    thisMayTakeMinutes =
        await translator.translate('thisMayTakeMinutes', c.locale);
    errorGettingData = await translator.translate('errorGettingData', c.locale);
    emailNotFound = await translator.translate('emailNotFound', c.locale);
    notRegistered = await translator.translate('notRegistered', c.locale);
    firstTime = await translator.translate('firstTime', c.locale);
    changeLanguage = await translator.translate('changeLanguage', c.locale);
    welcome = await translator.translate('welcome', c.locale);
    startEmailLinkSignin =
        await translator.translate('signInWithEmail', c.locale);
    signInWithPhone = await translator.translate('signInWithPhone', c.locale);
    setState(() {});
  }

  Future _navigateToColor() async {
    pp('$mm _navigateToColor ......');
    await navigateWithScale(
        LanguageAndColorChooser(
          onLanguageChosen: () {},
        ),
        context);
    colorAndLocale = await prefs.getColorAndLocale();
    await _setTexts();
  }

  Future<void> _navigateToEmailAuth() async {
    var res = await navigateWithScale(
        DamnEmailLink(
          onLanguageChosen: () {},
        ),
        context);
    pp('\n\n$mm ................ back from sign in: $res');
    user = await prefs.getUser();
    _getData(false);
  }

  Future<void> _navigateToMaps() async {
    await navigateWithScale(const AssociationRouteMaps(), context);
    user = await prefs.getUser();
    _getData(false);
  }

  Future<void> _navigateToRouteAssignments() async {
    await navigateWithScale(const RouteAssigner(), context);
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
      cars = await listApiDog.getOwnerVehicles(user!.userId!, true);
      pp('$mm _refreshBag: ${E.appleRed} '
          '\n🔴 cars: ${cars.length} '
          '\n🔴 vehicleHeartbeats: ${bigBag?.vehicleHeartbeats.length} '
          '\n🔴 vehicleArrivals: ${bigBag?.vehicleArrivals.length} '
          '\n🔴 dispatchRecords: ${bigBag?.dispatchRecords.length} '
          '\n🔴 passengerCounts: ${bigBag?.passengerCounts.length} '
          '\n🔴 vehicleDepartures: ${bigBag?.vehicleDepartures.length}');

      _calculateTotalPassengers();
    } catch (e, stack) {
      pp('$mm $e  - $stack');
      if (mounted) {
        showSnackBar(
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.redAccent,
            textStyle: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
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
    pp('$mm ............................ getting owner data ....');
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
      pp('$mm ............................ getting owner data: cars: ${cars.length}');

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
    } catch (e, stack) {
      pp('$mm $e  - $stack');
      if (mounted) {
        showSnackBar(
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.red,
            textStyle: const TextStyle(color: Colors.white),
            message: 'Error getting data: $e',
            context: context);
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
    pp('$mm .... _navigateToCarList ..........');
    await navigateWithScale(
        CarList(
          ownerId: user!.userId,
        ),
        context);
    pp('$mm .... back from car list');
  }

  Future<void> _navigateToScanner() async {
    await navigateWithScale(const ScanVehicleForOwner(), context);
    pp('$mm .... back from car update');
  }

  int days = 7;

  void _navigateToPhoneAuth() async {
    user = await navigateWithScale(
        CustomPhoneVerification(
          onUserAuthenticated: (user) {
            pp('$mm ... _navigateToPhoneAuth: onUserAuthenticated: ${user.name} ... IGNORE??? ');
            // this.user = user;
            // _getData(false);
          },
          onError: () {
            if (mounted) {
              showSnackBar(
                  message: 'Something went wrong. Please try again',
                  context: context);
            }
          },
          onCancel: () {},
          onLanguageChosen: () {
            _setTexts();
          },
        ),
        context);
    pp('\n\n\n$mm .... back from CustomPhoneVerification ... check user ...');

    if (user != null) {
      pp('$mm ... _navigateToPhoneAuth: back from CustomPhoneVerification with user: ${user!.name}');
      _getData(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          ownerDashboard == null ? 'Dashboard' : ownerDashboard!,
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
              icon: Icon(Icons.airport_shuttle,
                  color: Theme.of(context).primaryColor)),
          IconButton(
              onPressed: () {
                _navigateToRouteAssignments();
              },
              icon:
                  Icon(Icons.settings, color: Theme.of(context).primaryColor)),
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
                    gapH16,
                    user == null
                        ? const Text('....')
                        : Text(
                            user!.name,
                            style: myTextStyleSmall(context),
                          ),
                    gapH16,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          historyCars == null
                              ? 'History for all cars'
                              : historyCars!,
                          style: myTextStyleSmall(context),
                        ),
                        gapW16,
                        Text(
                          '$days',
                          style: myTextStyleMediumLargeWithColor(
                              context, Theme.of(context).primaryColor, 20),
                        ),
                        gapW32,
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
                    gapH32,
                    gapH16,
                    SizedBox(
                      width: 300,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _navigateToCarList();
                          },
                          icon: const Icon(Icons.list),
                          style: const ButtonStyle(
                            elevation: MaterialStatePropertyAll(12),
                          ),
                          label: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child:
                                SizedBox(width: 200, child: Text('View Cars')),
                          ),
                        ),
                      ),
                    ),
                    arrivalsText == null
                        ? gapW16
                        : Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CountsGridWidget(
                                passengerCounts: totalPassengers,
                                arrivalsText: arrivalsText!,
                                departuresText: departuresText!,
                                dispatchesText: dispatchesText!,
                                heartbeatText: heartbeatText!,
                                arrivals: bigBag == null
                                    ? 0
                                    : bigBag!.vehicleArrivals.length,
                                departures: bigBag == null
                                    ? 0
                                    : bigBag!.vehicleDepartures.length,
                                heartbeats: bigBag == null
                                    ? 0
                                    : bigBag!.vehicleHeartbeats.length,
                                dispatches: bigBag == null
                                    ? 0
                                    : bigBag!.dispatchRecords.length,
                                passengerCountsText: passengerCounts!,
                              ),
                            ),
                          )
                  ],
                ),
              ),
            ),
          ),
          busy
              ? Positioned(
                  left: 12,
                  right: 12,
                  bottom: 60,
                  top: 60,
                  child: Center(
                    child: TimerWidget(
                      title: loadingOwnerData == null
                          ? 'Loading Owner data'
                          : loadingOwnerData!,
                      subTitle: thisMayTakeMinutes == null
                          ? 'This may take a few minutes'
                          : thisMayTakeMinutes!,
                      isSmallSize: true,
                    ),
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
