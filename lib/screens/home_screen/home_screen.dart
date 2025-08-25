import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../generated/l10n.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../ytmusic/ytmusic.dart';
import 'section_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final YTMusic ytMusic = GetIt.I<YTMusic>();
  late ScrollController _scrollController;
  late List chips = [];
  late List sections = [];
  int page = 0;
  String? continuation;
  bool initialLoading = true;
  bool nextLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    fetchHome();
  }

  _scrollListener() async {
    if (initialLoading || nextLoading || continuation == null) {
      return;
    }
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      await fetchNext();
    }
  }

  fetchHome() async {
    setState(() {
      initialLoading = true;
      nextLoading = false;
    });
    Map<String, dynamic> home = await ytMusic.browse();
    if (mounted) {
      setState(() {
        initialLoading = false;
        nextLoading = false;
        chips = home['chips'];
        sections = home['sections'];
        continuation = home['continuation'];
      });
    }
  }

  refresh() async {
    if (initialLoading) return;
    Map<String, dynamic> home = await ytMusic.browse();
    if (mounted) {
      setState(() {
        initialLoading = false;
        nextLoading = false;
        chips = home['chips'];
        sections = home['sections'];
        continuation = home['continuation'];
      });
    }
  }

  fetchNext() async {
    if (continuation == null) return;
    setState(() {
      nextLoading = true;
    });
    Map<String, dynamic> home =
        await ytMusic.browseContinuation(additionalParams: continuation!);
    List<Map<String, dynamic>> secs =
        home['sections'].cast<Map<String, dynamic>>();
    if (mounted) {
      setState(() {
        sections.addAll(secs);
        continuation = home['continuation'];
        nextLoading = false;
      });
    }
  }

  Widget _horizontalChipsRow(List data) {
    var list = <Widget>[const SizedBox(width: 16)];
    for (var element in data) {
      list.add(
        AdaptiveInkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => context.go('/chip', extra: element),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4)),
            child: Text(element['title']),
          ),
        ),
      );
      list.add(const SizedBox(
        width: 8,
      ));
    }
    list.add(const SizedBox(
      width: 8,
    ));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list,
      ),
    );
  }

  // Helper for greeting message
  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 20) return 'Good Evening';
    return 'Good Night';
  }

  // Helper for music bar widget
  Widget _musicBar(Color color, double height) {
    return Container(
      width: 10,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 81, 0, 144), // Purple
                  Color.fromARGB(0, 0, 0, 0),
                ],
                stops: [0.0, 1.0],
              ),
            ),
          ),
        ),
        AdaptiveScaffold(
          appBar: PreferredSize(
            preferredSize: const AdaptiveAppBar().preferredSize,
            child: AdaptiveAppBar(
              automaticallyImplyLeading: false,
              title: Material(
                color: Colors.transparent,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/images/are.png',
                            height: 32,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'WITH ❤️ BY ROHIT PATIL',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 24, 177, 121),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        iconSize: 18,
                        icon: Icon(AdaptiveIcons.search, color: Colors.white),
                        onPressed: () => context.go('/search'),
                        tooltip: S.of(context).Search_Gyawun,
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: false,
            ),
          ),
          body: initialLoading
              ? const Center(child: AdaptiveProgressRing())
              : RefreshIndicator(
                  onRefresh: () => refresh(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    controller: _scrollController,
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Greeting bar
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            child: Container(
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // Greeting and message
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getGreetingMessage(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Discover new music and enjoy your day!',
                                            style: const TextStyle(
                                              color: Color.fromARGB(
                                                  255, 17, 207, 160),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // 3 colored music bars, aligned to bottom and moved left
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: SizedBox(
                                      height: 47,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            _musicBar(
                                                const Color.fromARGB(
                                                    255, 255, 255, 255),
                                                23),
                                            _musicBar(
                                                const Color.fromARGB(
                                                    255, 255, 255, 255),
                                                40),
                                            _musicBar(
                                                const Color.fromARGB(
                                                    255, 255, 255, 255),
                                                27),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _horizontalChipsRow(chips),
                          Column(
                            children: [
                              ...sections.map((section) {
                                return SectionItem(section: section);
                              }),
                              if (!nextLoading && continuation != null)
                                const SizedBox(height: 50),
                              if (nextLoading)
                                const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: AdaptiveProgressRing()),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
