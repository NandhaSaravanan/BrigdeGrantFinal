import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import '../widgets.dart';

class _Step {
  const _Step(this.title, this.body, [this.linkLabel, this.url]);

  final String title;
  final String body;
  final String? linkLabel;
  final String? url;
}

const _startSteps = [
  _Step(
    'Define your mission and build a founding board',
    'Write a short mission statement and recruit people with the skills '
        'you will need. Look up local nonprofits doing similar work under '
        'Explore → Recipients to learn from them or partner instead of '
        'duplicating.',
  ),
  _Step(
    'Incorporate as a South Carolina nonprofit',
    'File Articles of Incorporation for a nonprofit corporation with the '
        'SC Secretary of State.',
    'SC Secretary of State',
    'https://sos.sc.gov/',
  ),
  _Step(
    'Get an Employer Identification Number (EIN)',
    'An EIN is free from the IRS and is needed for bank accounts and '
        'tax-exempt status.',
    'IRS: Get an EIN',
    'https://www.irs.gov/businesses/small-businesses-self-employed/get-an-employer-identification-number',
  ),
  _Step(
    'Adopt bylaws and core policies',
    'Bylaws, a conflict-of-interest policy, and basic financial controls '
        'are expected by funders and the IRS.',
  ),
  _Step(
    'Apply for 501(c)(3) tax-exempt status',
    'Most groups file IRS Form 1023 or the shorter 1023-EZ if eligible.',
    'IRS: Applying for tax-exempt status',
    'https://www.irs.gov/charities-non-profits/applying-for-tax-exempt-status',
  ),
  _Step(
    'Register before asking the public for donations',
    'South Carolina generally requires charities to register with the '
        'Secretary of State before soliciting donations.',
    'SC Secretary of State',
    'https://sos.sc.gov/',
  ),
  _Step(
    'Stay compliant every year',
    'File the annual IRS Form 990-series return and keep state '
        'registrations current. Funders often review your 990.',
    'IRS: Annual filing and forms',
    'https://www.irs.gov/charities-non-profits/annual-filing-and-forms',
  ),
];

Future<void> _openLink(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }
}

/// Guidance for people starting or growing a nonprofit, plus a help request
/// form.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key, required this.onNavigate});

  final NavigateTo onNavigate;

  void _openForm(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const HelpRequestPage()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = isWide(context);

    final hero = HeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeroPill(
            icon: Icons.volunteer_activism_outlined,
            label: 'For nonprofit founders and leaders',
          ),
          const SizedBox(height: 16),
          Text(
            'Starting or growing a nonprofit?',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: BrandStyle.of(context).heroInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us what you are working on and what kind of help you need. '
            'We will follow up with resources or a connection.',
            style: TextStyle(
              color: BrandStyle.of(context).heroInk.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: BrandStyle.of(context).heroButtonBg,
              foregroundColor: BrandStyle.of(context).heroButtonInk,
            ),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.edit_note),
            label: const Text('Request help'),
          ),
        ],
      ),
    );

    final useApp = SectionCard(
      icon: Icons.lightbulb_outline,
      title: 'Use this app to research',
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.account_balance_outlined,
            color: Brand.accents[1],
            title: 'Find funders who give locally',
            body:
                'See which foundations reported grants in this area, '
                'how much, and to whom.',
            onTap: () => onNavigate(AppTab.explore, view: ExploreView.funders),
          ),
          _ActionRow(
            icon: Icons.groups_outlined,
            color: Brand.accents[3],
            title: 'Learn from peer nonprofits',
            body:
                'Look up organizations doing similar work and the funders '
                'that support them.',
            onTap: () =>
                onNavigate(AppTab.explore, view: ExploreView.recipients),
          ),
          _ActionRow(
            icon: Icons.tune,
            color: Brand.accents[0],
            title: 'Check typical grant sizes',
            body: 'Filter grants by city and amount to set a realistic ask.',
            onTap: () => onNavigate(AppTab.explore, view: ExploreView.grants),
          ),
        ],
      ),
    );

    final steps = SectionCard(
      icon: Icons.checklist,
      title: 'First steps to start a nonprofit in SC',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, step) in _startSteps.indexed)
            _StepRow(number: i + 1, step: step),
          const SizedBox(height: 4),
          Text(
            'General information, not legal or tax advice. Confirm current '
            'requirements and fees with the agencies linked above.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    const about = SectionCard(
      icon: Icons.info_outline,
      title: 'About this data',
      child: Text(
        'Grant records come from IRS Form 990 Schedule I and 990-PF filings, '
        'matched on filing ID, recipient, city, state, and amount. Use '
        '"Open source filing" on any grant to see the original.',
      ),
    );

    return ListView(
      padding: EdgeInsets.all(wide ? 24 : 16),
      children: [
        hero,
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: steps),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [useApp, const SizedBox(height: 16), about],
                ),
              ),
            ],
          )
        else ...[
          useApp,
          const SizedBox(height: 16),
          steps,
          const SizedBox(height: 16),
          about,
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.step});

  final int number;
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: BrandStyle.of(context).badgeGradient,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: BrandStyle.of(context).badgeInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  step.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (step.url != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openLink(context, step.url!),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(step.linkLabel!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Form that collects contact details and the kind of help needed.
class HelpRequestPage extends StatefulWidget {
  const HelpRequestPage({super.key});

  @override
  State<HelpRequestPage> createState() => _HelpRequestPageState();
}

class _HelpRequestPageState extends State<HelpRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _npo = TextEditingController();
  final _message = TextEditingController();
  final _helpTypes = <String>{};
  String? _stage;
  bool _consent = false;
  bool _showChoiceErrors = false;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _npo, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _showChoiceErrors = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || _helpTypes.isEmpty || !_consent) return;

    setState(() => _submitting = true);
    try {
      await GrantsScope.of(context).submitHelpRequest(
        HelpRequest(
          fullName: _name.text,
          email: _email.text,
          phone: _phone.text,
          npoName: _npo.text,
          stage: _stage,
          // Keep the option order stable regardless of tap order.
          helpTypes: [
            for (final key in helpTypeOptions.keys)
              if (_helpTypes.contains(key)) key,
          ],
          message: _message.text,
        ),
      );
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your request could not be sent. Check your connection and try '
            'again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request help')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _submitted ? _buildThanks(context) : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildThanks(BuildContext context) => MessageView(
    icon: Icons.mark_email_read_outlined,
    title: 'Thank you!',
    message:
        'We received your request and will contact you at '
        '${_email.text.trim()}.',
    action: FilledButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Done'),
    ),
  );

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final errorStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );

    InputDecoration deco(String label, IconData icon, {String? hint}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('How can we help?', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Share a few details and we will follow up. Fields marked * are '
            'required.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            icon: Icons.person_outline,
            title: 'Your details',
            child: Column(
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  controller: _name,
                  decoration: deco('Full name *', Icons.badge_outlined),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  maxLength: 120,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your name.'
                      : null,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _email,
                  decoration: deco('Email *', Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  maxLength: 254,
                  validator: (v) => isValidEmail(v ?? '')
                      ? null
                      : 'Enter a valid email address.',
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _phone,
                  decoration: deco('Phone', Icons.phone_outlined),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-.\s]')),
                  ],
                  maxLength: 32,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty || isValidPhone(v))
                      ? null
                      : 'Enter a valid phone number.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'Your nonprofit',
            child: Column(
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  controller: _npo,
                  decoration: deco(
                    'Nonprofit name',
                    Icons.apartment_outlined,
                    hint: 'Or the name you are planning',
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 200,
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _stage,
                  isExpanded: true,
                  decoration: deco('Where are you today?', Icons.flag_outlined),
                  items: [
                    for (final e in stageOptions.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _stage = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            icon: Icons.support_agent_outlined,
            title: 'Help needed *',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in helpTypeOptions.entries)
                      FilterChip(
                        label: Text(e.value),
                        selected: _helpTypes.contains(e.key),
                        onSelected: (on) => setState(
                          () => on
                              ? _helpTypes.add(e.key)
                              : _helpTypes.remove(e.key),
                        ),
                      ),
                  ],
                ),
                if (_showChoiceErrors && _helpTypes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Choose at least one kind of help.',
                      style: errorStyle,
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _message,
                  decoration: const InputDecoration(
                    labelText: 'Tell us more',
                    hintText: 'What are you working on? What would help most?',
                    alignLabelWithHint: true,
                  ),
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('I agree to be contacted about this request. *'),
            subtitle: _showChoiceErrors && !_consent
                ? Text('Please confirm to continue.', style: errorStyle)
                : null,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_submitting ? 'Sending…' : 'Send request'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
