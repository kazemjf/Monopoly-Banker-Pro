import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/editions.dart';
import '../main.dart';
import '../theme/themes.dart';
import 'game/game_screen.dart';

/// New-game wizard: edition → rules → players → starting player.
class NewGameWizardScreen extends StatefulWidget {
  const NewGameWizardScreen({super.key});
  @override
  State<NewGameWizardScreen> createState() => _NewGameWizardScreenState();
}

class _NewGameWizardScreenState extends State<NewGameWizardScreen> {
  int _step = 0;
  String _editionId = 'london';
  Edition? _edition;
  final _nameCtrl = TextEditingController();
  final _cashCtrl = TextEditingController(text: '1500');
  final _goCtrl = TextEditingController();
  final List<TextEditingController> _players = [];
  int _startingPlayer = 0;

  @override
  void initState() {
    super.initState();
    _players.addAll([TextEditingController(), TextEditingController()]);
    getEdition(_editionId).then((e) {
      if (mounted) {
        setState(() {
          _edition = e;
          _goCtrl.text = '${e.goSalary}';
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cashCtrl.dispose();
    _goCtrl.dispose();
    for (final c in _players) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickEdition(String id) async {
    final e = await getEdition(id);
    if (!mounted) return;
    setState(() {
      _editionId = id;
      _edition = e;
      _goCtrl.text = '${e.goSalary}';
    });
  }

  bool get _playersValid =>
      _players.where((c) => c.text.trim().isNotEmpty).length >= 2;

  Future<void> _create() async {
    final prefs = AppScope.of(context).prefs;
    final names = _players.map((c) => c.text.trim()).where((n) => n.isNotEmpty).toList();
    if (names.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prefs.t('newg.needPlayers'))),
      );
      return;
    }
    final game = await AppScope.of(context).games.createGame(
          name: _nameCtrl.text,
          editionId: _editionId,
          startCash: int.tryParse(_cashCtrl.text) ?? 1500,
          goSalary: int.tryParse(_goCtrl.text) ?? (_edition?.goSalary ?? 200),
          playerNames: names,
          startingPlayerIdx: _startingPlayer.clamp(0, names.length - 1),
        );
    if (!mounted) return;
    final edition = _edition ?? await getEdition(_editionId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(game: game, edition: edition)),
    );
    if (mounted) {
      // reset wizard for next time
      setState(() {
        _step = 0;
        _nameCtrl.clear();
        _startingPlayer = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final steps = [
      prefs.t('edition.title'),
      prefs.t('newg.title'),
      prefs.t('newg.players'),
      prefs.t('newg.startingPlayer'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(prefs.t('nav.newGame'))),
      body: Column(
        children: [
          _StepDots(step: _step, count: 4, palette: pal),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _stepBody(prefs, pal, steps),
            ),
          ),
          _navRow(prefs, pal),
        ],
      ),
    );
  }

  Widget _stepBody(prefs, AppPalette pal, List<String> steps) {
    switch (_step) {
      case 0:
        return _editionStep(prefs, pal);
      case 1:
        return _rulesStep(prefs, pal);
      case 2:
        return _playersStep(prefs, pal);
      default:
        return _startingStep(prefs, pal);
    }
  }

  // ---- step 1: vertical edition cards ----
  Widget _editionStep(prefs, AppPalette pal) {
    return ListView(
      key: const ValueKey('edition'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(prefs.t('edition.hint'), style: TextStyle(color: pal.muted, fontSize: 13)),
        const SizedBox(height: 12),
        for (final id in kEditionIds)
          _EditionCard(
            id: id,
            selected: _editionId == id,
            onTap: () => _pickEdition(id),
          ),
      ],
    );
  }

  // ---- step 2: name + rules ----
  Widget _rulesStep(prefs, AppPalette pal) {
    return ListView(
      key: const ValueKey('rules'),
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(prefs.t('newg.name')),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(hintText: prefs.t('newg.name')),
        ),
        SectionHeader(prefs.t('newg.startCash')),
        TextField(
          controller: _cashCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        SectionHeader(prefs.t('newg.goSalary')),
        TextField(
          controller: _goCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '${_edition?.goSalary ?? 200} (${_edition?.currencySymbol ?? '\$'})',
          ),
        ),
        const SizedBox(height: 8),
        if (_edition != null)
          Text(
            '${_edition!.localizedName(prefs.locale)} • ${_edition!.currencySymbol}',
            style: TextStyle(color: pal.muted, fontSize: 12),
          ),
      ],
    );
  }

  // ---- step 3: players ----
  Widget _playersStep(prefs, AppPalette pal) {
    return ListView(
      key: const ValueKey('players'),
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < _players.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _players[i],
                    decoration: InputDecoration(
                      hintText: prefs.t('newg.playerName', {'n': '${i + 1}'}),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_players.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: pal.danger),
                    tooltip: prefs.t('newg.removePlayer'),
                    onPressed: () {
                      setState(() {
                        _players[i].dispose();
                        _players.removeAt(i);
                        _startingPlayer = _startingPlayer.clamp(0, _players.length - 1);
                      });
                    },
                  ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _players.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: Text(prefs.t('newg.addPlayer')),
        ),
        if (!_playersValid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(prefs.t('newg.needPlayers'),
                style: TextStyle(color: pal.danger, fontSize: 12)),
          ),
      ],
    );
  }

  // ---- step 4: starting player ----
  Widget _startingStep(prefs, AppPalette pal) {
    final names = _players.map((c) => c.text.trim()).toList();
    return ListView(
      key: const ValueKey('starting'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(prefs.t('newg.startingPlayer'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        for (var i = 0; i < names.length; i++)
          if (names[i].isNotEmpty)
            Card(
              color: _startingPlayer == i ? pal.gold : pal.surface,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _startingPlayer == i ? pal.goldInk : pal.surface2,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: _startingPlayer == i ? pal.gold : pal.fg,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(names[i],
                    style: TextStyle(
                        color: _startingPlayer == i ? pal.goldInk : pal.fg,
                        fontWeight: FontWeight.w600)),
                trailing: _startingPlayer == i
                    ? Icon(Icons.check_circle, color: pal.goldInk)
                    : null,
                onTap: () => setState(() => _startingPlayer = i),
              ),
            ),
      ],
    );
  }

  Widget _navRow(prefs, AppPalette pal) {
    final last = _step == 3;
    final canNext = _step == 0 || _step == 1 || (_step == 2 && _playersValid);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  child: Text(prefs.t('action.back')),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: !canNext && !last
                    ? null
                    : () {
                        if (last) {
                          _create();
                        } else {
                          setState(() => _step++);
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(last ? prefs.t('newg.create') : prefs.t('action.confirm')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int step;
  final int count;
  final AppPalette palette;
  const _StepDots({required this.step, required this.count, required this.palette});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == step ? 28 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i <= step ? palette.gold : palette.line,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditionCard extends StatelessWidget {
  final String id;
  final bool selected;
  final VoidCallback onTap;
  const _EditionCard({required this.id, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? pal.gold.withValues(alpha: 0.14) : pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? pal.gold : pal.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: pal.felt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.map, color: pal.fg, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prefs.t(editionNameKey(id)),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: selected ? pal.gold : pal.fg),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prefs.t(editionDescKey(id)),
                      style: TextStyle(color: pal.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(Icons.check_circle, color: pal.gold, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
