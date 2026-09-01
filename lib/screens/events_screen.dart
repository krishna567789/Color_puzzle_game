import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../models/event_model.dart';
import '../core/audio_service.dart';
import '../widgets/common/coin_animation_overlay.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<GameEvent> _events = [];
  int _coins = 0;
  int _gems = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final coins = await StorageService.getCoins();
    final gems = await StorageService.getGems();
    
    // In a real app, these might come from a server
    List<GameEvent> templates = [
      GameEvent(
        id: 'summer_season_2026',
        title: 'SUMMER SPLASH',
        description: 'Complete 25 levels during the summer season to win big!',
        bannerImage: 'assets/images/onboarding2.png', // Using existing asset
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 8, 31),
        goal: 25,
        rewardCoins: 5000,
        rewardGems: 10,
      ),
      GameEvent(
        id: 'weekend_warrior',
        title: 'WEEKEND WARRIOR',
        description: 'Solve 5 puzzles this weekend!',
        bannerImage: 'assets/images/onboarding1.png',
        startDate: DateTime(2026, 8, 15), // Current time is Aug 19, Wed. Weekend was 15-16.
        endDate: DateTime(2026, 8, 23),
        goal: 5,
        rewardCoins: 1000,
        rewardGems: 2,
      ),
    ];

    List<GameEvent> loaded = [];
    for (var e in templates) {
      final data = await StorageService.getEventData(e.id);
      e.isClaimed = data['claimed'] ?? false;
      e.currentProgress = data['progress'] ?? 0;
      loaded.add(e);
    }

    setState(() {
      _events = loaded;
      _coins = coins;
      _gems = gems;
    });
  }

  Future<void> _claimReward(BuildContext buttonContext, GameEvent event) async {
    if (event.isClaimed || !event.isCompleted) return;

    setState(() {
      event.isClaimed = true;
      _coins += event.rewardCoins;
      _gems += event.rewardGems;
    });

    await StorageService.saveCoins(_coins);
    await StorageService.saveGems(_gems);
    await StorageService.saveEventProgress(event.id, true, event.currentProgress);
    
    AudioService.playWinSfx();
    
    if (event.rewardCoins > 0) {
      final renderBox = buttonContext.findRenderObject() as RenderBox?;
      Offset startOffset = Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
      if (renderBox != null) {
        final pos = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        startOffset = Offset(pos.dx + size.width / 2, pos.dy + size.height / 2);
      }
      
      CoinAnimationUtils.showCoinAnimation(
        context: context,
        startOffset: startOffset,
        endOffset: const Offset(40, 50),
        coinCount: 15,
      );
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Season Reward: ${event.rewardCoins} Coins Claimed!'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('LIMITED EVENTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Magical Background with Blur
          Positioned.fill(
            child: Image.asset(
              'assets/images/wizard_room_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),
          
          SafeArea(
            child: _events.isEmpty 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(_events[index]);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(GameEvent event) {
    bool isActive = event.isActive;
    bool canClaim = event.isCompleted && !event.isClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? AppColors.primaryButton.withValues(alpha: 0.6) : Colors.white12, 
          width: 1.5,
        ),
        boxShadow: [
          if (isActive) 
            BoxShadow(color: AppColors.primaryButton.withValues(alpha: 0.15), blurRadius: 30, spreadRadius: -5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Stack(
                children: [
                  Image.asset(
                    event.bannerImage,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    color: isActive ? null : Colors.grey.withValues(alpha: 0.6),
                    colorBlendMode: isActive ? null : BlendMode.saturation,
                  ),
                  // Banner Inner Shadow / Gradient Overlay for readability
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          AppColors.cardBackground.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  
                  if (isActive)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.redAccent, Colors.pink]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 10)],
                        ),
                        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                      ),
                    ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6), 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: Text('${event.daysRemaining}d Left', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title, 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 24, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description, 
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    
                    // Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: ${event.currentProgress}/${event.goal}', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        if (event.isClaimed)
                           const Text('CLAIMED', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1))
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Neon Progress Bar
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  width: constraints.maxWidth * event.progressPercentage,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: event.isCompleted 
                                        ? [Colors.green, Colors.greenAccent] 
                                        : [Colors.cyan, AppColors.primaryButton],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (event.isCompleted ? Colors.green : AppColors.primaryButton).withValues(alpha: 0.8),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: Builder(
                        builder: (btnContext) => GestureDetector(
                          onTap: canClaim ? () => _claimReward(btnContext, event) : (isActive ? () => Navigator.pop(context) : null),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: canClaim 
                                  ? [Colors.green, Colors.lightGreen] 
                                  : (isActive ? [AppColors.primaryButton, Colors.cyan] : [Colors.white10, Colors.black26]),
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                if (isActive || canClaim)
                                  BoxShadow(
                                    color: (canClaim ? Colors.green : AppColors.primaryButton).withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                              ],
                              border: Border.all(color: isActive ? Colors.white30 : Colors.white12, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                canClaim ? 'CLAIM REWARD' : (isActive ? 'PLAY NOW' : 'FINISHED'),
                                style: TextStyle(
                                  color: isActive || canClaim ? Colors.black87 : Colors.white54, 
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
