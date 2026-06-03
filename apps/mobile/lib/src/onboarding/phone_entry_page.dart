import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CountryCode {
  final String name;
  final String flag;
  final String code;
  final String pattern; // regex-like hint for number format

  const CountryCode(this.name, this.flag, this.code, this.pattern);

  static const List<CountryCode> all = [
    CountryCode('Afghanistan', '🇦🇫', '+93', '## ### ####'),
    CountryCode('Albania', '🇦🇱', '+355', '## ### ####'),
    CountryCode('Algeria', '🇩🇿', '+213', '## ### ####'),
    CountryCode('Andorra', '🇦🇩', '+376', '### ###'),
    CountryCode('Angola', '🇦🇴', '+244', '### ### ###'),
    CountryCode('Argentina', '🇦🇷', '+54', '## ##-####-####'),
    CountryCode('Armenia', '🇦🇲', '+374', '## ### ###'),
    CountryCode('Australia', '🇦🇺', '+61', '# #### ####'),
    CountryCode('Austria', '🇦🇹', '+43', '### ######'),
    CountryCode('Azerbaijan', '🇦🇿', '+994', '## ### ## ##'),
    CountryCode('Bahrain', '🇧🇭', '+973', '#### ####'),
    CountryCode('Bangladesh', '🇧🇩', '+880', '## ### ###'),
    CountryCode('Belarus', '🇧🇾', '+375', '## ### ## ##'),
    CountryCode('Belgium', '🇧🇪', '+32', '### ## ## ##'),
    CountryCode('Benin', '🇧🇯', '+229', '## ## ## ##'),
    CountryCode('Bolivia', '🇧🇴', '+591', '# ### ####'),
    CountryCode('Bosnia', '🇧🇦', '+387', '## ### ###'),
    CountryCode('Botswana', '🇧🇼', '+267', '## ### ###'),
    CountryCode('Brazil', '🇧🇷', '+55', '(##) ####-####'),
    CountryCode('Brunei', '🇧🇳', '+673', '### ####'),
    CountryCode('Bulgaria', '🇧🇬', '+359', '### ### ###'),
    CountryCode('Burkina Faso', '🇧🇫', '+226', '## ## ## ##'),
    CountryCode('Burundi', '🇧🇮', '+257', '## ## ## ##'),
    CountryCode('Cambodia', '🇰🇭', '+855', '## ### ###'),
    CountryCode('Cameroon', '🇨🇲', '+237', '### ### ###'),
    CountryCode('Canada', '🇨🇦', '+1', '(###) ###-####'),
    CountryCode('Cape Verde', '🇨🇻', '+238', '### ## ##'),
    CountryCode('Central African Rep.', '🇨🇫', '+236', '## ## ## ##'),
    CountryCode('Chad', '🇹🇩', '+235', '## ## ## ##'),
    CountryCode('Chile', '🇨🇱', '+56', '# #### ####'),
    CountryCode('China', '🇨🇳', '+86', '### #### ####'),
    CountryCode('Colombia', '🇨🇴', '+57', '### ### ####'),
    CountryCode('Comoros', '🇰🇲', '+269', '## ## ##'),
    CountryCode('Congo', '🇨🇬', '+242', '### ### ###'),
    CountryCode('Costa Rica', '🇨🇷', '+506', '#### ####'),
    CountryCode('Croatia', '🇭🇷', '+385', '## ### ###'),
    CountryCode('Cuba', '🇨🇺', '+53', '# ### ####'),
    CountryCode('Cyprus', '🇨🇾', '+357', '## ### ###'),
    CountryCode('Czech Republic', '🇨🇿', '+420', '### ### ###'),
    CountryCode('Denmark', '🇩🇰', '+45', '## ## ## ##'),
    CountryCode('Djibouti', '🇩🇯', '+253', '## ## ## ##'),
    CountryCode('Dominican Rep.', '🇩🇴', '+1-809', '### ### ####'),
    CountryCode('DR Congo', '🇨🇩', '+243', '### ### ###'),
    CountryCode('Ecuador', '🇪🇨', '+593', '## ### ####'),
    CountryCode('Egypt', '🇪🇬', '+20', '### ### ####'),
    CountryCode('El Salvador', '🇸🇻', '+503', '#### ####'),
    CountryCode('Equatorial Guinea', '🇬🇶', '+240', '## ### ####'),
    CountryCode('Eritrea', '🇪🇷', '+291', '# ### ###'),
    CountryCode('Estonia', '🇪🇪', '+372', '### ####'),
    CountryCode('Eswatini', '🇸🇿', '+268', '## ## ####'),
    CountryCode('Ethiopia', '🇪🇹', '+251', '## ### ####'),
    CountryCode('Fiji', '🇫🇯', '+679', '## #####'),
    CountryCode('Finland', '🇫🇮', '+358', '## ### ####'),
    CountryCode('France', '🇫🇷', '+33', '# ## ## ## ##'),
    CountryCode('Gabon', '🇬🇦', '+241', '## ## ## ##'),
    CountryCode('Gambia', '🇬🇲', '+220', '### ####'),
    CountryCode('Georgia', '🇬🇪', '+995', '### ### ###'),
    CountryCode('Germany', '🇩🇪', '+49', '### ######'),
    CountryCode('Ghana', '🇬🇭', '+233', '## ### ####'),
    CountryCode('Greece', '🇬🇷', '+30', '### ### ####'),
    CountryCode('Guatemala', '🇬🇹', '+502', '#### ####'),
    CountryCode('Guinea', '🇬🇳', '+224', '### ### ###'),
    CountryCode('Guyana', '🇬🇾', '+592', '### ####'),
    CountryCode('Haiti', '🇭🇹', '+509', '## ## ####'),
    CountryCode('Honduras', '🇭🇳', '+504', '#### ####'),
    CountryCode('Hong Kong', '🇭🇰', '+852', '#### ####'),
    CountryCode('Hungary', '🇭🇺', '+36', '## ### ####'),
    CountryCode('Iceland', '🇮🇸', '+354', '### ####'),
    CountryCode('India', '🇮🇳', '+91', '##### #####'),
    CountryCode('Indonesia', '🇮🇩', '+62', '## ### ####'),
    CountryCode('Iran', '🇮🇷', '+98', '### ### ####'),
    CountryCode('Iraq', '🇮🇶', '+964', '### ### ####'),
    CountryCode('Ireland', '🇮🇪', '+353', '## ### ####'),
    CountryCode('Israel', '🇮🇱', '+972', '## ### ####'),
    CountryCode('Italy', '🇮🇹', '+39', '### ### ####'),
    CountryCode('Ivory Coast', '🇨🇮', '+225', '## ## ## ##'),
    CountryCode('Jamaica', '🇯🇲', '+1-876', '### ### ####'),
    CountryCode('Japan', '🇯🇵', '+81', '## #### ####'),
    CountryCode('Jordan', '🇯🇴', '+962', '# #### ####'),
    CountryCode('Kazakhstan', '🇰🇿', '+7', '### ### ## ##'),
    CountryCode('Kenya', '🇰🇪', '+254', '### ### ###'),
    CountryCode('Kuwait', '🇰🇼', '+965', '#### ####'),
    CountryCode('Kyrgyzstan', '🇰🇬', '+996', '### ### ###'),
    CountryCode('Laos', '🇱🇦', '+856', '## ### ###'),
    CountryCode('Latvia', '🇱🇻', '+371', '## ### ###'),
    CountryCode('Lebanon', '🇱🇧', '+961', '## ### ###'),
    CountryCode('Liberia', '🇱🇷', '+231', '### ### ####'),
    CountryCode('Libya', '🇱🇾', '+218', '## ### ###'),
    CountryCode('Liechtenstein', '🇱🇮', '+423', '### ###'),
    CountryCode('Lithuania', '🇱🇹', '+370', '### ###'),
    CountryCode('Luxembourg', '🇱🇺', '+352', '### ###'),
    CountryCode('Madagascar', '🇲🇬', '+261', '## ## ###'),
    CountryCode('Malawi', '🇲🇼', '+265', '# ### ###'),
    CountryCode('Malaysia', '🇲🇾', '+60', '## ### ####'),
    CountryCode('Maldives', '🇲🇻', '+960', '### ####'),
    CountryCode('Mali', '🇲🇱', '+223', '## ## ## ##'),
    CountryCode('Malta', '🇲🇹', '+356', '## ### ###'),
    CountryCode('Mauritania', '🇲🇷', '+222', '## ## ## ##'),
    CountryCode('Mauritius', '🇲🇺', '+230', '### ####'),
    CountryCode('Mexico', '🇲🇽', '+52', '## #### ####'),
    CountryCode('Moldova', '🇲🇩', '+373', '## ### ###'),
    CountryCode('Monaco', '🇲🇨', '+377', '## ### ###'),
    CountryCode('Mongolia', '🇲🇳', '+976', '## ## ####'),
    CountryCode('Montenegro', '🇲🇪', '+382', '## ### ###'),
    CountryCode('Morocco', '🇲🇦', '+212', '## ### ####'),
    CountryCode('Mozambique', '🇲🇿', '+258', '## ### ###'),
    CountryCode('Myanmar', '🇲🇲', '+95', '## ### ###'),
    CountryCode('Namibia', '🇳🇦', '+264', '## ### ####'),
    CountryCode('Nepal', '🇳🇵', '+977', '## ### ###'),
    CountryCode('Netherlands', '🇳🇱', '+31', '## ### ####'),
    CountryCode('New Zealand', '🇳🇿', '+64', '## ### ####'),
    CountryCode('Nicaragua', '🇳🇮', '+505', '#### ####'),
    CountryCode('Niger', '🇳🇪', '+227', '## ## ## ##'),
    CountryCode('Nigeria', '🇳🇬', '+234', '### ### ####'),
    CountryCode('North Korea', '🇰🇵', '+850', '## ### ###'),
    CountryCode('North Macedonia', '🇲🇰', '+389', '## ### ###'),
    CountryCode('Norway', '🇳🇴', '+47', '### ## ###'),
    CountryCode('Oman', '🇴🇲', '+968', '## ### ###'),
    CountryCode('Pakistan', '🇵🇰', '+92', '### ### ####'),
    CountryCode('Palestine', '🇵🇸', '+970', '## ### ####'),
    CountryCode('Panama', '🇵🇦', '+507', '### ####'),
    CountryCode('Papua New Guinea', '🇵🇬', '+675', '### ###'),
    CountryCode('Paraguay', '🇵🇾', '+595', '## ### ####'),
    CountryCode('Peru', '🇵🇪', '+51', '### ### ###'),
    CountryCode('Philippines', '🇵🇭', '+63', '### ### ####'),
    CountryCode('Poland', '🇵🇱', '+48', '### ### ###'),
    CountryCode('Portugal', '🇵🇹', '+351', '## ### ####'),
    CountryCode('Qatar', '🇶🇦', '+974', '#### ####'),
    CountryCode('Romania', '🇷🇴', '+40', '### ### ###'),
    CountryCode('Russia', '🇷🇺', '+7', '### ### ## ##'),
    CountryCode('Rwanda', '🇷🇼', '+250', '### ### ###'),
    CountryCode('Saudi Arabia', '🇸🇦', '+966', '## ### ####'),
    CountryCode('Senegal', '🇸🇳', '+221', '## ### ####'),
    CountryCode('Serbia', '🇷🇸', '+381', '## ### ####'),
    CountryCode('Sierra Leone', '🇸🇱', '+232', '## ######'),
    CountryCode('Singapore', '🇸🇬', '+65', '#### ####'),
    CountryCode('Slovakia', '🇸🇰', '+421', '### ### ###'),
    CountryCode('Slovenia', '🇸🇮', '+386', '## ### ###'),
    CountryCode('Somalia', '🇸🇴', '+252', '# ### ###'),
    CountryCode('South Africa', '🇿🇦', '+27', '## ### ####'),
    CountryCode('South Korea', '🇰🇷', '+82', '## ### ####'),
    CountryCode('South Sudan', '🇸🇸', '+211', '### ### ###'),
    CountryCode('Spain', '🇪🇸', '+34', '### ### ###'),
    CountryCode('Sri Lanka', '🇱🇰', '+94', '## ### ####'),
    CountryCode('Sudan', '🇸🇩', '+249', '## ### ####'),
    CountryCode('Suriname', '🇸🇷', '+597', '### ###'),
    CountryCode('Sweden', '🇸🇪', '+46', '## ### ####'),
    CountryCode('Switzerland', '🇨🇭', '+41', '## ### ## ##'),
    CountryCode('Syria', '🇸🇾', '+963', '## ### ###'),
    CountryCode('Taiwan', '🇹🇼', '+886', '# #### ####'),
    CountryCode('Tajikistan', '🇹🇯', '+992', '## ### ####'),
    CountryCode('Tanzania', '🇹🇿', '+255', '## ### ####'),
    CountryCode('Thailand', '🇹🇭', '+66', '## ### ####'),
    CountryCode('Togo', '🇹🇬', '+228', '## ### ###'),
    CountryCode('Trinidad & Tobago', '🇹🇹', '+1-868', '### ### ####'),
    CountryCode('Tunisia', '🇹🇳', '+216', '## ### ###'),
    CountryCode('Turkey', '🇹🇷', '+90', '### ### ####'),
    CountryCode('Turkmenistan', '🇹🇲', '+993', '## ### ###'),
    CountryCode('Uganda', '🇺🇬', '+256', '### ### ###'),
    CountryCode('Ukraine', '🇺🇦', '+380', '## ### ## ##'),
    CountryCode('UAE', '🇦🇪', '+971', '## ### ####'),
    CountryCode('United Kingdom', '🇬🇧', '+44', '#### ######'),
    CountryCode('United States', '🇺🇸', '+1', '(###) ###-####'),
    CountryCode('Uruguay', '🇺🇾', '+598', '# ### ####'),
    CountryCode('Uzbekistan', '🇺🇿', '+998', '## ### ## ##'),
    CountryCode('Vatican City', '🇻🇦', '+379', '## ####'),
    CountryCode('Venezuela', '🇻🇪', '+58', '### ### ####'),
    CountryCode('Vietnam', '🇻🇳', '+84', '## ### ## ##'),
    CountryCode('Yemen', '🇾🇪', '+967', '### ### ###'),
    CountryCode('Zambia', '🇿🇲', '+260', '## ### ####'),
    CountryCode('Zimbabwe', '🇿🇼', '+263', '## ### ###'),
  ];
}

class PhoneEntryPage extends StatefulWidget {
  final bool isTour; // if true, show "skip" option
  const PhoneEntryPage({super.key, this.isTour = false});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final _phoneController = TextEditingController();
  late CountryCode _selectedCountry;
  bool _isSearching = false;
  List<CountryCode> _filteredCountries = CountryCode.all;

  @override
  void initState() {
    super.initState();
    _selectedCountry = CountryCode.all.firstWhere(
      (c) => c.code == '+1',
      orElse: () => CountryCode.all.first,
    );
    _filteredCountries = CountryCode.all;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _e164Phone => '$_selectedCountry.code${_phoneController.text.replaceAll(RegExp(r'[\s\-\(\)]'), '')}';

  bool get _isValidPhone => _e164Phone.length >= 8 && _e164Phone.length <= 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        actions: widget.isTour
            ? [TextButton(onPressed: () => context.push('/home'), child: const Text('Skip'))]
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your phone number',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll send you a verification code",
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: InkWell(
                    onTap: _showCountryPicker,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Country'),
                      child: Row(
                        children: [
                          Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedCountry.code,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: _selectedCountry.pattern,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isValidPhone
                  ? () => context.push('/onboarding/verify', extra: _e164Phone)
                  : null,
              child: const Text('Send Code'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search countries...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) {
                  setSheetState(() {
                    _isSearching = v.isNotEmpty;
                    _filteredCountries = CountryCode.all.where((c) =>
                      c.name.toLowerCase().contains(v.toLowerCase()) ||
                      c.code.contains(v),
                    ).toList();
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredCountries.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        '${_filteredCountries.length} countries',
                        style: theme.textTheme.labelSmall,
                      ),
                    );
                  }
                  final c = _filteredCountries[i - 1];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.name, style: const TextStyle(fontSize: 14)),
                    trailing: Text(c.code, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    onTap: () {
                      setState(() => _selectedCountry = c);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
