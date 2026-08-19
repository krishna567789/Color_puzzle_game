import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../models/event_model.dart';
import '../core/audio_service.dart';

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

  Future<void> _claimReward(GameEvent event) async {
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
      backgroundColor: AppColors.background,
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
      body: _events.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              return _buildEventCard(_events[index]);
            },
          ),
    );
  }

  Widget _buildEventCard(GameEvent event) {
    bool isActive = event.isActive;
    bool canClaim = event.isCompleted && !event.isClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isActive ? AppColors.primaryButton.withOpacity(0.5) : AppColors.cardBorder, width: 2),
        boxShadow: [
          if (isActive) BoxShadow(color: AppColors.primaryButton.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: Image.asset(
                  event.bannerImage,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  color: isActive ? null : Colors.grey.withOpacity(0.5),
                  colorBlendMode: isActive ? null : BlendMode.saturation,
                ),
              ),
              if (isActive)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text('${event.daysRemaining}d Left', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(event.description, style: const TextStyle(color: Colors.white60, fontSize: 14)),
                const SizedBox(height: 20),
                
                // Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress: ${event.currentProgress}/${event.goal}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    if (event.isClaimed)
                       const Text('CLAIMED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: event.progressPercentage,
                    minHeight: 12,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(event.isCompleted ? Colors.green : AppColors.primaryButton),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canClaim ? () => _claimReward(event) : (isActive ? () => Navigator.pop(context) : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canClaim ? Colors.green : (isActive ? AppColors.primaryButton : Colors.white10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      canClaim ? 'CLAIM REWARD' : (isActive ? 'PLAY NOW' : 'FINISHED'),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
