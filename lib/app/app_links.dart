/// Every address this app will ever hand to a browser. There is one.
library;

/// The public repository.
///
/// This app's whole claim is a negative one — no account, no server, no
/// telemetry, nothing leaves the phone — and a negative claim cannot be
/// demonstrated by an app about itself. The repository is the part a reader
/// who does not take it on trust can go and check, which is why the link is in
/// Settings rather than only in a store listing.
final Uri kSourceRepositoryUrl = Uri.https(
  'github.com',
  '/zakariaf/NearlyStop',
);

/// The repository as it is shown to a reader.
///
/// Spelled out on the row, not hidden behind a word: somebody deciding whether
/// to trust a medical app wants to see WHERE they are being sent before they
/// tap, and `https://` in front of it is noise to the audience this is for.
const String kSourceRepositoryLabel = 'github.com/zakariaf/NearlyStop';
