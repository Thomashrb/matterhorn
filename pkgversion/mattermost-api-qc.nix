{ mkDerivation, base, containers, mattermost-api, QuickCheck
, stdenv, text, time
}:
mkDerivation {
  pname = "mattermost-api-qc";
  version = "50200.1.0";
  sha256 = "bfe9e1d69dcd6314219969c65078f8172f6ddd47ce4e1dfee716e38b1bc09fe6";
  libraryHaskellDepends = [
    base containers mattermost-api QuickCheck text time
  ];
  doCheck = false;
  homepage = "https://github.com/matterhorn-chat/mattermost-api-qc";
  description = "QuickCheck instances for the Mattermost client API library";
  license = stdenv.lib.licenses.isc;
}
