import 'dart:async';

import 'package:kyndrel/features/cast/cast_device.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// Finds Chromecasts (`_googlecast._tcp`) with mDNS.
Future<List<CastDevice>> discoverChromecasts({
  Duration timeout = const Duration(seconds: 3),
}) async {
  final client = MDnsClient();
  final found = <String, CastDevice>{};
  try {
    await client.start();
    await for (final ptr
        in client
            .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer('_googlecast._tcp.local'),
            )
            .timeout(timeout, onTimeout: (sink) => sink.close())) {
      final name = ptr.domainName;
      var friendly = name.split('._googlecast').first;
      await for (final txt
          in client
              .lookup<TxtResourceRecord>(ResourceRecordQuery.text(name))
              .timeout(
                const Duration(seconds: 1),
                onTimeout: (s) => s.close(),
              )) {
        friendly = friendlyNameFromTxt(txt.text) ?? friendly;
      }
      await for (final srv
          in client
              .lookup<SrvResourceRecord>(ResourceRecordQuery.service(name))
              .timeout(
                const Duration(seconds: 1),
                onTimeout: (s) => s.close(),
              )) {
        await for (final ip
            in client
                .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target),
                )
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: (s) => s.close(),
                )) {
          found[name] = CastDevice(
            id: 'cc:$name',
            name: friendly,
            kind: CastKind.chromecast,
            host: ip.address.address,
            port: srv.port,
          );
        }
      }
    }
  } on Object {
    // No multicast (VPN, firewall): nothing found.
  } finally {
    client.stop();
  }
  return found.values.toList();
}

/// `fn=Living Room TV` from a Chromecast TXT record.
String? friendlyNameFromTxt(String txt) {
  for (final part in txt.split(RegExp(r'[\n\x00-\x1f]'))) {
    if (part.startsWith('fn=')) return part.substring(3);
  }
  return null;
}
