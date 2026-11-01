"""Isolated loopback QA certificates. Never install this CA in an OS trust store."""
from pathlib import Path
from datetime import datetime, timedelta, timezone
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
import ipaddress, sys
root = Path(__file__).resolve().parents[3] / 'deploy/product/.local/validation/secrets'
root.mkdir(parents=True, exist_ok=True)
if sys.argv[1:] != ['--isolated-loopback']:
    raise RuntimeError('Explicit isolated QA only')
if (root / 'pg_ca.crt').exists():
    print('Existing isolated QA certificates preserved')
    sys.exit(0)
now = datetime.now(timezone.utc)
key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Mohammad Style isolated QA CA')])
ca = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
      .serial_number(x509.random_serial_number()).not_valid_before(now - timedelta(minutes=5))
      .not_valid_after(now + timedelta(days=7)).add_extension(x509.BasicConstraints(ca=True, path_length=0), True)
      .add_extension(x509.KeyUsage(False,False,False,False,False,True,True,False,False),True).sign(key, hashes.SHA256()))
(root / 'pg_ca.crt').write_bytes(ca.public_bytes(serialization.Encoding.PEM))
for prefix, names in [('pg_server', ['postgres', 'localhost']), ('https', ['localhost'])]:
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, names[0])])
    cert = (x509.CertificateBuilder().subject_name(subject).issuer_name(name).public_key(private.public_key())
            .serial_number(x509.random_serial_number()).not_valid_before(now - timedelta(minutes=5))
            .not_valid_after(now + timedelta(days=7)).add_extension(x509.BasicConstraints(ca=False,path_length=None),True)
            .add_extension(x509.SubjectAlternativeName([*[x509.DNSName(n) for n in names],x509.IPAddress(ipaddress.ip_address('127.0.0.1'))]),False)
            .add_extension(x509.ExtendedKeyUsage([x509.oid.ExtendedKeyUsageOID.SERVER_AUTH]),False).sign(key,hashes.SHA256()))
    (root / (prefix + '.crt')).write_bytes(cert.public_bytes(serialization.Encoding.PEM))
    (root / (prefix + '.key')).write_bytes(private.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
print('Created seven-day private loopback QA certificates; no trust store changed; signing key discarded')
