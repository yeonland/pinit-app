import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'designs.dart';
import 'my_reference.dart';
import 'public_shop.dart';
import 'pinit_colors.dart';
import 'shop.dart';

// ---------------------------------------------------------------------------
// 📍 지도 탐색 화면 - OpenStreetMap 지도 + 샵 핀 + 예약 채널(네이버/카톡/인스타) 연결
// 처음엔 지도만 보이고, 핀을 누르면 하단에 샵 카드가 뜸 (빈 곳을 누르면 닫힘)
// ---------------------------------------------------------------------------
class MultiChannelMapExplorerScreen extends StatefulWidget {
  final List<Shop> shops;
  // '이 샵으로 예약 양식 쓰기' (shop·category만 담아서 넘김)
  final ValueChanged<Map<String, String>>? onReserve;

  const MultiChannelMapExplorerScreen({super.key, this.shops = pinitShops, this.onReserve});

  @override
  State<MultiChannelMapExplorerScreen> createState() => _MultiChannelMapExplorerScreenState();
}

class _MultiChannelMapExplorerScreenState extends State<MultiChannelMapExplorerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '전체';
  List<PublicShop> _publicShops = []; // 공공데이터(소상공인 상가정보) 서울·부산 실제 샵

  // 지금 카드로 보고 있는 샵 (둘 중 하나만 선택됨, 둘 다 null이면 카드 없음)
  Shop? _selectedShop;
  PublicShop? _selectedPublic;

  // 이 배율 이상 확대하면 모든 핀에 샵 이름 표시
  static const double _labelZoom = 17;
  // 공공데이터 샵이 수만 곳이라 화면 안에 있는 것만, 어느 정도 확대했을 때만 그림
  static const double _minPinZoom = 13;
  static const int _maxPins = 600;
  double _zoom = 15;
  LatLngBounds? _visibleBounds;
  bool get _showAllLabels => _zoom >= _labelZoom;

  List<PublicShop> get _filteredPublic => _selectedCategory == '전체'
      ? _publicShops
      : _publicShops.where((place) => place.category == _selectedCategory).toList();

  // 지금 화면에 보이는 공공데이터 샵 (너무 축소했으면 그리지 않음)
  List<PublicShop> get _visiblePublic {
    final bounds = _visibleBounds;
    if (bounds == null || _zoom < _minPinZoom) return const [];
    return _filteredPublic
        .where((place) => bounds.contains(LatLng(place.lat, place.lng)))
        .take(_maxPins)
        .toList();
  }

  void _updateCamera(MapCamera camera) {
    setState(() {
      _zoom = camera.zoom;
      _visibleBounds = camera.visibleBounds;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPublicShops();
  }

  Future<void> _loadPublicShops() async {
    try {
      final shops = await loadPublicShops();
      if (mounted) setState(() => _publicShops = shops);
    } catch (_) {
      // 데이터를 못 읽어도 직접 등록한 샵은 그대로 보여줌
    }
  }

  List<Shop> get _filteredShops => _selectedCategory == '전체'
      ? widget.shops
      : widget.shops.where((shop) => shop.category == _selectedCategory).toList();

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _selectedShop = null;
      _selectedPublic = null;
    });
  }

  void _onShopTap(Shop shop) {
    setState(() {
      _selectedShop = shop;
      _selectedPublic = null;
    });
    _mapController.move(shop.location, _mapController.camera.zoom);
  }

  void _onPublicTap(PublicShop place) {
    setState(() {
      _selectedShop = null;
      _selectedPublic = place;
    });
    _mapController.move(LatLng(place.lat, place.lng), _mapController.camera.zoom);
  }

  // 샵 이름으로 검색: 직접 등록한 샵 → 공공데이터 샵 순서로 찾아서 카드 열기
  void _search(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();

    final shop = widget.shops.where((s) => s.name.contains(q)).firstOrNull;
    final place = shop == null ? _publicShops.where((n) => n.name.contains(q)).firstOrNull : null;
    if (shop == null && place == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'$q' 이름의 샵을 찾지 못했어요.")));
      return;
    }

    // 지금 카테고리에서 안 보이는 샵이면 전체로 바꿔서 보여줌
    if ((shop != null && !_filteredShops.contains(shop)) || (place != null && !_filteredPublic.contains(place))) {
      setState(() => _selectedCategory = '전체');
    }
    final zoom = _mapController.camera.zoom < 16 ? 16.0 : _mapController.camera.zoom;
    if (shop != null) {
      _onShopTap(shop);
      _mapController.move(shop.location, zoom);
    } else {
      _onPublicTap(place!);
      _mapController.move(LatLng(place.lat, place.lng), zoom);
    }
  }

  void _closeCard() {
    setState(() {
      _selectedShop = null;
      _selectedPublic = null;
    });
  }

  Future<void> _openLink(Uri uri, String channelName) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('$channelName 링크를 열 수 없어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredShops = _filteredShops;
    final hasCard = _selectedShop != null || _selectedPublic != null;
    // 샵 카드 대신 하단 가운데에 띄울 안내 문구
    final String? notice = filteredShops.isEmpty && _filteredPublic.isEmpty
        ? '이 카테고리에는 아직 등록된 샵이 없어요.'
        : !hasCard && _publicShops.isNotEmpty && _zoom < _minPinZoom
            ? '지도를 확대하면 샵이 보여요.'
            : null;
    // 넓은 화면에선 샵 카드를 오른쪽 패널로 (안내 문구는 그대로 하단 가운데)
    final sidePanel = notice == null && MediaQuery.sizeOf(context).width >= pinitWideWidth;

    return Stack(
      children: [
        // 1. 실제 지도 (OpenStreetMap)
        FlutterMap(
          mapController: _mapController,
          // 처음엔 아무 샵도 고르지 않은 채 강남역 주변을 보여줌
          options: MapOptions(
            initialCenter: gangnamStation,
            initialZoom: 15,
            onTap: (_, _) => _closeCard(),
            onMapReady: () => _updateCamera(_mapController.camera),
            onPositionChanged: (camera, _) => _updateCamera(camera),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.pinit_app',
            ),
            // 모든 샵은 같은 점으로 표시, 누르거나 크게 확대하면 이름표로 바뀜 (고른 샵은 맨 위에)
            MarkerLayer(
              markers: [
                for (final place in _visiblePublic)
                  if (place != _selectedPublic)
                    _buildMarker(
                      point: LatLng(place.lat, place.lng),
                      label: '${place.category.split(' ').first} ${place.name}',
                      isSelected: false,
                      onTap: () => _onPublicTap(place),
                    ),
                for (final shop in filteredShops)
                  if (shop != _selectedShop)
                    _buildMarker(
                      point: shop.location,
                      label: '${shop.category.split(' ').first} ${shop.name}',
                      isSelected: false,
                      onTap: () => _onShopTap(shop),
                    ),
                if (_selectedPublic case final place?)
                  _buildMarker(
                    point: LatLng(place.lat, place.lng),
                    label: '${place.category.split(' ').first} ${place.name}',
                    isSelected: true,
                    onTap: () => _onPublicTap(place),
                  ),
                if (_selectedShop case final shop?)
                  _buildMarker(
                    point: shop.location,
                    label: '${shop.category.split(' ').first} ${shop.name}',
                    isSelected: true,
                    onTap: () => _onShopTap(shop),
                  ),
              ],
            ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),

        // 2. 샵 이름 검색
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Material(
            elevation: 3,
            shadowColor: Colors.black26,
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: _publicShops.isEmpty ? '샵 이름 검색' : '샵 이름 검색 (서울·부산 실제 샵 ${_publicShops.length}곳)',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: IconButton(
                  tooltip: '검색',
                  icon: const Icon(Icons.arrow_forward, size: 20, color: pinitAccentDark),
                  onPressed: () => _search(_searchController.text),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // 3. 카테고리 필터
        Positioned(
          top: 68,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final category in ['전체', ...shopCategories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          color: _selectedCategory == category ? Colors.white : Colors.black87,
                          fontWeight: _selectedCategory == category ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: _selectedCategory == category,
                      onSelected: (_) => _selectCategory(category),
                      selectedColor: pinitAccentDark,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      elevation: 3,
                      shadowColor: Colors.black26,
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 4. 핀을 눌렀을 때만 샵 카드 표시 (폰: 하단 / 넓은 화면: 필터 아래 오른쪽 패널)
        if (hasCard || notice != null)
          Positioned(
            top: sidePanel ? 116 : null,
            bottom: sidePanel ? null : 28,
            left: sidePanel ? null : 16,
            right: 16,
            width: sidePanel ? 400 : null,
            child: notice != null
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(notice),
                    ),
                  )
                : _selectedShop != null
                    ? _buildShopCard(_selectedShop!)
                    : _buildPublicCard(_selectedPublic!),
          ),
      ],
    );
  }

  // 카드 공통 틀: 이름 줄 + 내용 + 닫기 버튼
  Widget _buildCardFrame({required String title, List<Widget> badges = const [], required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              ...badges,
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: '닫기',
                visualDensity: VisualDensity.compact,
                onPressed: _closeCard,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, {bool outlined = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? null : Colors.grey.withValues(alpha: 0.2),
        border: outlined ? Border.all(color: Colors.grey) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: outlined ? 10 : 11,
          color: outlined ? Colors.grey : null,
          fontWeight: outlined ? null : FontWeight.bold,
        ),
      ),
    );
  }

  // 직접 등록한 샵 카드: 등록된 채널만 버튼으로 표시
  Widget _buildShopCard(Shop shop) {
    final instagramUri = shop.instagramUri;
    final kakaoUri = shop.kakaoUri;

    return _buildCardFrame(
      title: shop.name,
      badges: [
        if (shop.isSample) _buildBadge('예시', outlined: true),
        _buildBadge('강남역 ${shop.distanceLabel}'),
      ],
      children: [
        Text(
          '${shop.category} · ${shop.address}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (shop.price != null) ...[
          const SizedBox(height: 4),
          Text(
            shop.price!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
        _buildDesignStrip(shop.name),
        const SizedBox(height: 12),
        // 네이버는 링크가 없으면 지도 검색으로 연결
        Row(
          children: [
            _buildChannelButton(
              label: 'N 네이버',
              color: naverGreen,
              textColor: Colors.white,
              onPressed: () => _openLink(shop.naverUri, '네이버'),
            ),
            if (kakaoUri != null)
              _buildChannelButton(
                label: '💬 카톡문의',
                color: kakaoYellow,
                textColor: Colors.black87,
                onPressed: () => _openLink(kakaoUri, '카카오톡'),
              ),
            if (instagramUri != null)
              _buildChannelButton(
                label: '📸 인스타',
                color: instagramPink,
                textColor: Colors.white,
                onPressed: () => _openLink(instagramUri, '인스타그램'),
              ),
          ],
        ),
        _buildReserveButton(shop.name, shop.category),
      ],
    );
  }

  // 공공데이터 샵 카드: 예약 채널이 없어서 네이버 지도 검색으로 연결
  Widget _buildPublicCard(PublicShop place) {
    final distance = const Distance().as(LengthUnit.Meter, gangnamStation, LatLng(place.lat, place.lng));
    final distanceLabel = distance < 1000 ? '${distance.round()}m' : '${(distance / 1000).toStringAsFixed(1)}km';

    return _buildCardFrame(
      title: place.name,
      // 부산처럼 먼 곳은 강남역 기준 거리가 의미 없어서 뺌
      badges: [if (distance < 30000) _buildBadge('강남역 $distanceLabel')],
      children: [
        Text(
          '${place.category} · ${place.fullAddress}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        const Text(
          '출처: 소상공인시장진흥공단 상가(상권)정보 · 예약 채널 미등록',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildChannelButton(
              label: 'N 네이버 지도에서 보기',
              color: naverGreen,
              textColor: Colors.white,
              onPressed: () => _openLink(Uri.https('map.naver.com', '/p/search/${place.name}'), '네이버'),
            ),
          ],
        ),
        _buildReserveButton(place.name, place.category),
      ],
    );
  }

  // 이 샵의 디자인 사진 (핀잇에 등록된 디자인이 있을 때만)
  Widget _buildDesignStrip(String shopName) {
    final designs = pinitDesigns.where((design) => design['shop'] == shopName).toList();
    if (designs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: designs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 72, height: 72, child: referenceImage(designs[index])),
          ),
        ),
      ),
    );
  }

  // 핀잇 예약 양식으로 이동 (샵 이름 자동 입력)
  Widget _buildReserveButton(String shopName, String category) {
    final onReserve = widget.onReserve;
    if (onReserve == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: pinitAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.edit_note, size: 20),
          label: const Text('이 샵으로 예약 양식 쓰기', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => onReserve({'shop': shopName, 'category': category}),
        ),
      ),
    );
  }

  Widget _buildChannelButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ),
    );
  }

  // 평소엔 점, 고른 샵이거나 크게 확대했을 때는 이름표
  Marker _buildMarker({
    required LatLng point,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final showLabel = isSelected || _showAllLabels;
    return Marker(
      point: point,
      width: showLabel ? 140 : 22,
      height: showLabel ? 36 : 22,
      child: GestureDetector(
        onTap: onTap,
        child: Center(child: showLabel ? _buildNamePin(label, isSelected) : _buildDot()),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: pinitAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _buildNamePin(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? pinitAccentDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinitAccentDark, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isSelected ? Colors.white : pinitAccentDark,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
