# Bluesky handle setup for mike.pixor.net

Use the existing account currently known as `flyingyeti.com`; do not create a
new account. Public DNS and the Bluesky resolveHandle API both returned
`did:plc:dtf7zmcsjtwedsdbdaxhfkrj`. Its public DID document currently claims
`at://flyingyeti.com` and uses the Bluesky PDS
`https://russula.us-west.host.bsky.network`.

Status: the zone candidate passed validation, but publishing requires
interactive sudo on `epic3`. Completion requires both live TXT verification and
the account's DID document claiming the new handle.

## Required record

```dns
_atproto.mike 300 IN TXT "did=did:plc:dtf7zmcsjtwedsdbdaxhfkrj"
```

This creates `_atproto.mike.pixor.net`. It does not change apex email MX or
SPF/DKIM records. DNS verification needs no web server, certificate, or A record.
The DNS value and the DID's claimed handle must agree. See the
[AT Protocol handle specification](https://atproto.com/specs/handle).

## Prepared candidate

The [candidate](evidence/pixor.net.with-atproto.zone) has serial `2026100201`.
On 2026-10-02 it was uploaded to the private directory
`/tmp/pixor-atproto.PjreDB` on `epic3`; `named-checkzone pixor.net` reported `OK`.
The directory is temporary and may disappear after reboot or cleanup. If it is
missing, upload the candidate again and update the path below. If the live zone
has changed, rebuild the addition against the current zone with a higher serial.

Candidate SHA-256:

```text
f4f72be7ce133ef9a96de419a3996e70d9a71d81a8a3a6e33cf11affc147b116
```

## Publish from an interactive session on epic3

Check that the source has not changed since the candidate was prepared:

```bash
printf '%s\n' 'bdb390dee5d8f29fd790f431744bc7d3d1d7307a8a5ddf4729b22f7c6492aa81  /etc/bind/master/pixor.net' | sha256sum -c -
```

Proceed only when this reports `OK`. Then check the candidate and its diff:

```bash
sha256sum /tmp/pixor-atproto.PjreDB/pixor.net
named-checkzone pixor.net /tmp/pixor-atproto.PjreDB/pixor.net
diff -u /etc/bind/master/pixor.net /tmp/pixor-atproto.PjreDB/pixor.net
```

The only record changes should be the serial and `_atproto.mike`. `diff` exits
with status 1 when files differ, which is expected here. Back up outside
`/etc/bind/master`: the legacy generator treats files inside that directory as
zone names. Use a fresh backup filename if one already exists.

```bash
sudo cp -p /etc/bind/master/pixor.net /var/backups/pixor.net.pre-atproto-20261002
sudo install -o root -g bind -m 0644 /tmp/pixor-atproto.PjreDB/pixor.net /etc/bind/master/pixor.net
sudo named-checkzone pixor.net /etc/bind/master/pixor.net
sudo rndc reload pixor.net
```

Run each command only after the previous one succeeds. Do not stage or commit
the entire legacy BIND repo: it already has unrelated staged/unstaged changes.

## Verify authoritative DNS and public caches

```bash
dig @45.79.94.199 _atproto.mike.pixor.net TXT +norecurse +short
dig @23.239.7.131 _atproto.mike.pixor.net TXT +norecurse +short
dig @1.1.1.1 _atproto.mike.pixor.net TXT +short
dig @8.8.8.8 _atproto.mike.pixor.net TXT +short
```

All should eventually return the exact `did=did:plc:dtf7zmcsjtwedsdbdaxhfkrj`
value. Cached wildcard answers previously had TTL 600 seconds, so allow those
to expire. Both authoritative addresses are on the same host; these checks do
not imply independent redundancy. Recheck apex MX, SPF, and all three DKIM
CNAMEs against the original snapshot.

## Finish in Bluesky

In the existing account, open Settings → Account → Handle → I have my own
domain, enter `mike.pixor.net`, verify the DNS record, and save the handle.
See [Bluesky's custom-domain instructions](https://bsky.social/about/blog/4-28-2023-domain-handle-tutorial).
This step changes the existing account's handle from `flyingyeti.com`.

Verify the public API and DID document afterward:

```bash
curl --fail --silent --show-error 'https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle?handle=mike.pixor.net'
curl --fail --silent --show-error 'https://plc.directory/did:plc:dtf7zmcsjtwedsdbdaxhfkrj'
```

The resolver should return the same DID. The DID document must include
`at://mike.pixor.net` in `alsoKnownAs`. A TXT record alone does not complete the
account change. Keep the existing `flyingyeti.com` record during setup.

## Rollback

If the new zone fails to load, restore the backed-up records, validate them,
and reload the zone. If the new serial was ever served, advance the restored
zone to a serial greater than the published value before reloading, rather
than reintroducing `2021102501`. If the Bluesky account change was already
saved, change its handle back to `flyingyeti.com` before removing the new TXT.
