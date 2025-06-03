{ myLib, lib, ... }:
let
  inherit (builtins)
    toString
    mapAttrs
    concatStringsSep
    attrValues
    ;
  inherit (lib.strings) concatLines;
  inherit (lib.lists) optional;
  inherit (myLib) keepAttrs;

  mkRootCA =
    pkgs:
    {
      # Generator optoins
      share ? false,
      deploy ? !share,
      owner ? "root",
      group ? owner,
      restartUnits ? [ ],

      # CA options
      pathlen ? 1,
      keyUsage ? "critical,keyCertSign,cRLSign",
      days ? 3650,
      subj ? "",
    }:
    {
      inherit share;
      files = {
        "key" = {
          inherit
            owner
            group
            deploy
            restartUnits
            ;
        };
        "cert" = {
          inherit restartUnits;
          deploy = false;
          secret = false;
        };
        "chain" = {
          inherit restartUnits;
          deploy = false;
          secret = false;
        };
        "fullchain" = {
          inherit restartUnits;
          deploy = false;
          secret = false;
        };
      };
      runtimeInputs = [
        pkgs.openssl
      ];
      validation = {
        inherit
          pathlen
          keyUsage
          subj
          days
          ;
      };
      script = ''
        openssl ecparam \
          -name prime256v1 \
          -genkey \
          -noout \
          -out "$out/key"

        openssl req -x509 -new -nodes \
          -addext "basicConstraints=critical,CA:TRUE,pathlen:${toString pathlen}" \
          -addext "keyUsage=${keyUsage}" \
          -addext "subjectKeyIdentifier=hash" \
          -key "$out/key" \
          -sha256 \
          -days "${toString days}" \
          -out "$out/cert" \
          -subj "${subj}"

        # Root cert is not included in chain/fullchain
        touch "$out/chain"
        touch "$out/fullchain"
      '';
    };

  mkSignedCert =
    pkgs:
    {
      # Generator options
      signer,
      share ? false,
      deploy ? !share,
      owner ? "root",
      group ? owner,
      restartUnits ? [ ],

      # CA options
      subj ? "",
      days ? 3650,
      extfile ? ''
        basicConstraints=critical,CA:FALSE
        keyUsage=critical,digitalSignature,keyEncipherment
      '',
    }:
    {
      inherit share;
      files = {
        "key" = {
          inherit
            owner
            group
            deploy
            restartUnits
            ;
        };
        "cert" = {
          inherit restartUnits;
          deploy = false;
          secret = false;
        };
        "chain" = {
          inherit restartUnits;
          deploy = false;
          secret = false;
        };
        "fullchain" = {
          inherit restartUnits;
          deploy = false;
          secret = false;
        };
      };
      runtimeInputs = [
        pkgs.openssl
      ];
      dependencies = [ signer ];
      validation = {
        inherit
          signer
          subj
          days
          ;
      };
      script = ''
        openssl ecparam \
          -name prime256v1 \
          -genkey \
          -noout \
          -out "$out/key"

        # Generate CSR (Certificate Signing Request)
        openssl req -new \
            -key "$out/key" \
            -out cert.csr \
            -subj "${subj}"

        # Sign CSR with signer CA
        openssl x509 -req \
          -in cert.csr \
          -CA "$in/${signer}/cert" \
          -CAkey "$in/${signer}/key" \
          -sha256 \
          -days "${toString days}" \
          -out "$out/cert" \
          -extfile <(cat <<EOF
        ${extfile}
        EOF
        )

        # Chains are ordered from leaf to root
        # Chain is all intermediate certificates (no root, no leaf)
        cp "$in/${signer}/fullchain" "$out/chain"
        # Fullchain is all certificates except root
        cat "$out/cert" "$out/chain" > "$out/fullchain"
      '';
    };

  mkPasswords =
    pkgs: passwords:
    let
      defaultPasswordSettings = {
        length = 64;

        secure = true;

        capitalize = true;
        numerals = true;
        symbols = true;
      };
      passwordToCommand =
        name: settings:
        let
          s = defaultPasswordSettings // settings;
        in
        concatStringsSep " " (
          [
            "pwgen"
            "-1"
          ]
          ++ (optional s.capitalize "--capitalize")
          ++ (optional s.numerals "--numerals")
          ++ (optional s.symbols "--symbols")
          ++ (optional s.secure "--secure")
          ++ [
            (toString s.length)
            "> \"$out/${name}\""
          ]
        );

      # Copied from: https://git.clan.lol/clan/clan-core/src/commit/fde68877547f3de4b8ce83ee4ff232d4f1718313/nixosModules/clanCore/vars/interface.nix#L169-L326
      fileAttributeNames = [
        "name"
        "generatorName"
        "share"
        "deploy"
        "secret"
        "neededFor"
        "owner"
        "group"
        "mode"
        "restartUnits"
      ];
    in
    {
      files = mapAttrs (_: keepAttrs fileAttributeNames) passwords;
      script = concatLines (attrValues (mapAttrs passwordToCommand passwords));
      runtimeInputs = [
        pkgs.pwgen
      ];
    };

in
{
  inherit mkRootCA mkSignedCert mkPasswords;
}
