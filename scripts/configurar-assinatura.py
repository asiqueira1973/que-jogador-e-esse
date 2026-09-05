#!/usr/bin/env python3
"""
Aponta o projeto tvOS para assinatura MANUAL de App Store, achando sozinho o perfil instalado.

Por que manual: a assinatura automatica do Xcode provisiona um perfil de *Development* mesmo ao
arquivar em Release — e perfil de Development exige um aparelho registrado no time. Como nao ha
Apple TV registrada, o archive falha. Perfil de App Store nao usa aparelho, mas o Xcode so o
utiliza se a assinatura for manual e o perfil for indicado pelo nome.

Uso: python3 scripts/configurar-assinatura.py
"""
import glob, os, plistlib, re, subprocess, sys

BUNDLE = "com.dablab.quejogadoreesse"
PASTA = os.path.expanduser("~/Library/Developer/Xcode/UserData/Provisioning Profiles")


def ler_perfil(caminho):
    """Os .mobileprovision sao PKCS#7 assinados; `security cms -D` extrai o plist de dentro."""
    try:
        bruto = subprocess.run(["security", "cms", "-D", "-i", caminho],
                               capture_output=True, check=True).stdout
        return plistlib.loads(bruto)
    except Exception:
        return None


def eh_app_store_tvos(perfil):
    """Perfil de App Store PARA tvOS.

    Checar a plataforma e essencial: o portal da Apple tem uma opcao "App Store Connect" que gera
    perfil de iOS/visionOS/watchOS e uma "tvOS App Store Connect" separada. As duas passam em
    qualquer teste que olhe so bundle id e ausencia de aparelhos — e o erro so aparece la na
    frente, no archive, como "platforms ... does not match the current platform tvOS"."""
    sem_aparelhos = not perfil.get("ProvisionedDevices")
    nao_e_dev = not perfil.get("Entitlements", {}).get("get-task-allow")
    plataformas = perfil.get("Platform") or []
    return sem_aparelhos and nao_e_dev and "tvOS" in plataformas


candidatos = []
for caminho in glob.glob(f"{PASTA}/*.mobileprovision"):
    perfil = ler_perfil(caminho)
    if not perfil:
        continue
    app_id = perfil.get("Entitlements", {}).get("application-identifier", "")
    if app_id.split(".", 1)[-1] != BUNDLE or not eh_app_store_tvos(perfil):
        continue
    candidatos.append((perfil.get("ExpirationDate"), perfil["Name"], perfil["UUID"], caminho))

if not candidatos:
    print(f"Nenhum perfil de App Store *de tvOS* para {BUNDLE} encontrado em:\n  {PASTA}")
    print("\nCrie em developer.apple.com → Profiles → + → secao Distribution → *tvOS* App Store Connect.")
    print("Cuidado: a opcao \"App Store Connect\" sem \"tvOS\" gera perfil de iOS e nao serve.")
    sys.exit(1)

candidatos.sort(reverse=True)          # o de validade mais longa
_, nome, uuid, caminho = candidatos[0]
print(f"perfil encontrado: {nome}")
print(f"  uuid: {uuid}")

p = "tvos-app/project.yml"
s = open(p, encoding="utf-8").read()
antes = s

# A base segue automatica (simulador nao assina); so Release vira manual.
s = re.sub(r"( *)Release:\n(?:(?:\1  .*|\s*#.*)\n)*",
           f"""\\1Release:
\\1  # Assinatura MANUAL: a automatica provisiona perfil de Development ao arquivar, e perfil de
\\1  # Development exige aparelho registrado no time — que este projeto nao tem. Perfil de App
\\1  # Store nao usa aparelho. Regerar este bloco com scripts/configurar-assinatura.py.
\\1  CODE_SIGNING_ALLOWED: YES
\\1  CODE_SIGN_STYLE: Manual
\\1  CODE_SIGN_IDENTITY: "Apple Distribution"
\\1  PROVISIONING_PROFILE_SPECIFIER: "{nome}"
""", s, count=1)

if s == antes:
    print("nao consegui reescrever o bloco Release do project.yml — ajuste a mao")
    sys.exit(1)

open(p, "w", encoding="utf-8").write(s)
print("\nproject.yml atualizado. Rode: cd tvos-app && xcodegen generate")
