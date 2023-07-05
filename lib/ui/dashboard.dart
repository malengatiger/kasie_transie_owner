import 'package:flutter/material.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/big_bag.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/number_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    user = await prefs.getUser();
    if (user == null) {
      _navigateToSignIn();
    } else {
      _getData(false);
    }
  }

  void _navigateToSignIn() async {
    pp('$mm ... _navigateToSignIn ...');
    var res = await navigateWithScale(
        CellPhoneAuthSignin(dataApiDog: dataApiDog), context);
    pp('\n\nmm .... back from sign in : $res');
    _getData(false);
  }

  Future _getData(bool refresh) async {
    pp('$mm .... getting owner data ....');
    //todo - add feature to pick start date
    try {
      setState(() {
        busy = true;
      });
      user = await prefs.getUser();
      final date = DateTime.now().toUtc().subtract(const Duration(days: 90));
      cars = await listApiDog.getOwnerVehicles(user!.userId!, refresh);
      bigBag =
          await listApiDog.getOwnersBag(user!.userId!, date.toIso8601String());
    } catch (e) {
      pp(e);
    }
    setState(() {
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Owner Dashboard',
          style: myTextStyleLarge(context),
        ),
        actions: [
          IconButton(
              onPressed: () {
                _getData(true);
              },
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: busy
          ? const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  backgroundColor: Colors.pink,
                ),
              ),
            )
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    shape: getRoundedBorder(radius: 16),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 64,
                              ),
                              const Text('Number of Cars'),
                              const SizedBox(width: 12,),
                              Text('${cars.length}',
                                style: myTextStyleMediumLargeWithColor(context, Theme.of(context).primaryColor,
                                    28),),
                            ],
                          ),
                          Text(user!.name, style: myTextStyleSmall(context),),

                          const SizedBox(
                            height: 64,
                          ),
                          bigBag == null
                              ? const SizedBox()
                              : Expanded(
                                  child: GridView(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 2,
                                          mainAxisSpacing: 2),
                                  children: [
                                    NumberWidget(
                                      title: 'Arrivals',
                                      number: bigBag!.vehicleArrivals.length,
                                    ),
                                    NumberWidget(
                                      title: 'Departures',
                                      number: bigBag!.vehicleDepartures.length,
                                    ),
                                    NumberWidget(
                                      title: 'Dispatches',
                                      number: bigBag!.dispatchRecords.length,
                                    ),
                                    NumberWidget(
                                      title: 'Heartbeats',
                                      number: bigBag!.vehicleHeartbeats.length,
                                    ),
                                  ],
                                ))
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
    ));
  }
}
