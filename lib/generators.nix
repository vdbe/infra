{ lib, ... }:
let
  mkRootCA =
    pkgs:
    {
      # Generator optoins
      share ? false,
      deploy ? !share,
      owner ? "root",
      group ? owner,

      # CA options
      pathlen ? 1,
      keyUsage ? "critical,keyCertSign,cRLSign",
      days ? 3650,
      subj ? "/CN=/C=/ST=/L=/O=",
    }:
    {
      inherit share;
      files = {
        "key" = {
          inherit owner group deploy;
        };
        "cert" = {
          deploy = false;
          secret = false;
        };
        "chain" = {
          deploy = false;
          secret = false;
        };
        "fullchain" = {
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
          -days ${toString days} \
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
          inherit owner group deploy;
        };
        "cert" = {
          deploy = false;
          secret = false;
        };
        "chain" = {
          deploy = false;
          secret = false;
        };
        "fullchain" = {
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
            -out cert \
            -subj "${subj}"

        # Sign CSR with signer CA
        openssl x509 -req \
          -in cert.csr \
          -CA "$in"/${signer}/cert \
          -CAkey "$in"/${signer}/key \
          -sha256 \
          -days ${toString days} \
          -out "$out/cert " \
          -extfile <(cat <<EOF
        ${extfile}
        EOF)

        # Chains are ordered from leaf to root
        # Chain is all intermediate certificates (no root, no leaf)
        cp "$in/${signer}/fullchain" "$out/chain"
        # Fullchain is all certificates except root
        cat "$out/cert" "$out/chain" > "$out/fullchain"
      '';
    };

in
{
  inherit mkRootCA mkSignedCert;
}
