"""A Python Pulumi program"""

from os import PathLike, environ
from pathlib import Path
import subprocess
import shutil
import tempfile
import json

from pulumi import InvokeOptions, ResourceOptions
import pulumi_cloudflare as cloudflare
from pulumi_cloudflare import (
    Provider as CloudflareProvider,
    ZeroTrustTunnelCloudflaredConfigConfigArgs,
    ZeroTrustAccessIdentityProviderConfigArgs,
    ZeroTrustAccessIdentityProviderScimConfigArgs,
)

VARS_DIRECTORY = "../vars"
DOMAIN = "ewood.dev"
FLAKE = Path("../.").absolute()


def binary_exists(name):
    return shutil.which(name) is not None


class BinaryNotFound(FileNotFoundError):
    def __init__(self, binary):
        self.path = binary
        super().__init__(binary)


class ClanVarNotFound(FileNotFoundError):
    def __init__(self, machine: str | None, generator: str, file: str, secret: bool):
        self.generator = generator
        self.machine = machine
        self.file = file
        self.secret = secret

        msg = self.construct_msg()
        msg.append("not found")

        super().__init__(" ".join(msg))

    def construct_msg(self) -> list[str]:
        vars_path = Path(VARS_DIRECTORY)

        if not vars_path.is_dir():
            return "Vars directory not found"

        msg = [f"{self.machine or 'shared'} generator '{self.generator}'"]
        generator_path = vars_path.joinpath(
            "shared" if self.machine is None else f"per-machine/{self.machine}",
            self.generator,
        )
        if not generator_path.is_dir():
            return msg

        file_path = generator_path.joinpath(self.file)
        msg.append(f"file '{self.file}'")
        if not file_path.is_dir():
            return msg

        secret_or_value = "secret" if self.secret else "value"
        msg.append(secret_or_value)
        full_path = generator_path.joinpath(secret_or_value)
        if not full_path.is_file():
            return msg

        raise AssertionError("Clan var does exist?")


def nix_eval(expr: str):
    expr = f'''
    let
        self =  builtins.getFlake "{FLAKE}";
        lib = self.inputs.nixpkgs.lib;
        myLib = self.lib;
    in
    {expr}
    '''

    with tempfile.NamedTemporaryFile(delete=True, mode="w") as expr_file:
        expr_file.write(expr)
        expr_file.flush()

        command = ["nix", "eval", "--impure", "--json", "--file", expr_file.name]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        # TODO: error handling
        return result.stdout


def decrypt_sops(file_path: PathLike, key_file: PathLike | None = None) -> str:
    file_path = Path(file_path)

    if not shutil.which("sops"):
        raise BinaryNotFound("sops")

    if not file_path.is_file():
        raise FileNotFoundError(f"Sops file not found: {file_path}")

    env = environ.copy()
    if key_file:
        env["SOPS_AGE_KEY_FILE"] = key_file

    command = ["sops", "--decrypt", file_path]
    try:
        result = subprocess.run(
            command, env=env, capture_output=True, text=True, check=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print("Sops error:\n", e.stderr)
        raise RuntimeError()


def get_var(
    generator: str,
    file: str,
    secret: bool = True,
    machine: str | None = None,
    key_file: PathLike | None = None,
) -> str:
    paths_parts = [
        VARS_DIRECTORY,
        "shared" if machine is None else f"per-machine/{machine}",
        generator,
        file,
        "secret" if secret else "value",
    ]
    var_file_path = Path(*paths_parts)

    try:
        if secret:
            return decrypt_sops(var_file_path, key_file=key_file)
        else:
            return var_file_path.read_text()

    except FileNotFoundError:
        raise ClanVarNotFound(machine, generator, file, secret)


def cloudflare_setup(provider: CloudflareProvider, key_file: PathLike | None = None):
    opts = {"provider": provider}

    # Get account and zone id from api provider for `DOMAIN`
    zones = cloudflare.get_zones(opts=InvokeOptions(**opts))

    zone = next(filter(lambda zone: zone.name == DOMAIN, zones.results))
    account_id = zone.account.id
    zone_id = zone.id

    existing_dns_records = cloudflare.get_dns_records(
        zone_id=zone_id,
        opts=InvokeOptions(**opts),
        comment={
            #  Comments the poor mans tags
            "contains": "managed-by:infra",
        },
    )
    # Can't use this see: https://github.com/cloudflare/terraform-provider-cloudflare/issues/5524
    # existing_tunnels = cloudflare.get_zero_trust_tunnel_cloudflareds(account_id=account_id, opts=opts)

    tunnel_machines = json.loads(
        nix_eval('self.lib.helpers.getMachinesSettings "tunnel" "default"')
    )

    for name, settings in tunnel_machines.items():
        # Can't create tunnel if a tunnel with the same name already exists
        # and can't import existing tunnel (see comment for `existing_tunnels`)
        # Create tunnel
        # tunnel = cloudflare.ZeroTrustTunnelCloudflared(
        #     f"zeroTrustTunnelCloudflaredResource{name.capitalize()}",
        #     account_id = account_id,
        #     name = f"infra-{name}",
        #     config_src="cloudflare",
        #     tunnel_secret = get_var("cloudflared", "tunnel-token", machine=name, key_file=key_file),
        #     opts=pulumi.ResourceOptions(provider=provider)
        #  )

        ingresses = list(settings["ingress"].values())
        ingresses.append(settings["default"])

        config = ZeroTrustTunnelCloudflaredConfigConfigArgs(
            ingresses=ingresses,
            origin_request=settings["origin_request"],
        )

        # Create tunnel config
        tunnel = cloudflare.ZeroTrustTunnelCloudflaredConfig(
            f"zeroTrustTunnelCloudflaredConfigResource{name.capitalize()}",
            account_id=account_id,
            tunnel_id=settings[
                "tunnel_id"
            ],  # Can get this from `tunnel` if we can import it
            source="cloudflare",
            config=config,
            opts=ResourceOptions(**opts),
        )

        # Create dns records for the tunnel
        for ingress in ingresses[:-1]:
            hostname = ingress["hostname"]
            if hostname == DOMAIN:
                record = "@"
            else:
                record = hostname.removesuffix(f".{DOMAIN}")

            conflicting_record_types = ["CNAME", "A", "AAAA"]
            existing_record = next(
                (
                    filter(
                        lambda record: record.name == hostname
                        and record.type in conflicting_record_types,
                        existing_dns_records.results,
                    )
                ),
                None,
            )

            record_name = f"dnsRecordResource{''.join(map(str.capitalize, record.split('.')))}CNAME"
            _dns_record = cloudflare.DnsRecord(
                record_name,
                name=record,
                ttl=1,
                zone_id=zone_id,
                comment=f"managed-by:infra machine:{name}",
                proxied=True,
                type="CNAME",
                content=tunnel.id.apply(lambda id: f"{id}.cfcargotunnel.com"),
                opts=ResourceOptions(
                    id=f"{zone_id}/{existing_record.id}" if existing_record else None,
                    **opts,
                ),
            )
            pass
        pass
    pass

    # Setup generic oauth
    existing_identity_providers = cloudflare.get_zero_trust_access_identity_providers(
        # account_id = account_id,
        zone_id=zone_id,
        opts=InvokeOptions(**opts),
    )
    print(json.dumps(existing_identity_providers.results, indent=True))
    existing_identity_provider = next(
        filter(
            lambda provider: provider.type == "oidc" and provider.name == "kanidm",
            existing_identity_providers.results,
        ),
        None,
    )

    client_id = "cloudflare-zero-trust"
    config = ZeroTrustAccessIdentityProviderConfigArgs(
        claims=[],
        scopes=["openidemailprofile"],
        client_id=client_id,
        client_secret=get_var(
            "kanidm-oauth2",
            "cloudflare-zero-trust",
            machine="arnold",
            key_file=age_keyfile.name,
        ),
        auth_url=f"https://idm.{DOMAIN}/ui/oauth2",
        token_url=f"https://idm.{DOMAIN}/oauth2/token",
        certs_url=f"https://idm.{DOMAIN}/oauth2/openid/{client_id}/public_key.jwk",
        pkce_enabled=True,
    )
    scim_config = ZeroTrustAccessIdentityProviderScimConfigArgs(
        enabled=False,
        identity_update_behavior="automatic",
        user_deprovision=True,
        seat_deprovision=True,
    )
    _identity_provider = cloudflare.ZeroTrustAccessIdentityProvider(
        "zeroTrustAccessIdentityProviderResourceKanidm",
        name="kanidm",
        zone_id=zone_id,
        type="oidc",
        config=config,
        scim_config=scim_config,
        opts=ResourceOptions(
            id=f"zones/{zone_id}/{existing_identity_provider.id}"
            if existing_identity_provider
            else None,
            **opts,
        ),
    )


with tempfile.NamedTemporaryFile(delete=True, mode="w") as age_keyfile:
    # TODO: figure out how decrypt with yubikey in python
    # pulumi doesn't seem to accept and input from stdin
    age_keyfile.write(get_var("terraform", "age-key.txt"))
    age_keyfile.flush()

    cloudflare_api_token = get_var("cloudflare", "api-token", key_file=age_keyfile.name)
    cf_provider = cloudflare.Provider("cf", api_token=cloudflare_api_token)

    cloudflare_setup(cf_provider, key_file=age_keyfile.name)
