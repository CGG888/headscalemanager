import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/services/derp_service.dart';

/// DERP 探测里的纯函数测试（不发起网络请求）。
///
/// 背景：Headscale 的 API 不提供 DERP 信息，「每台机器当前用哪个中继」只能在该
/// 设备上看；但「中继列表 + 从本机到各中继的延迟」可以像 Tailscale 的 netcheck
/// 那样探测出来。这里覆盖解析与排序这两处关键逻辑。
void main() {
  group('parseBootstrapDns', () {
    test('提取主机名，跳过解析失败的条目并去重排序', () {
      const body = '{"derp2.tailscale.com":["5.6.7.8"],'
          '"derp1.tailscale.com":["1.2.3.4"],'
          '"unresolved.example.com":[],'
          '"derp2.tailscale.com":["5.6.7.8"]}';
      expect(DerpService.parseBootstrapDns(body),
          ['derp1.tailscale.com', 'derp2.tailscale.com']);
    });

    test('非 JSON（例如被劫持到门户页）返回空列表而不是抛异常', () {
      expect(DerpService.parseBootstrapDns('<html>captive portal</html>'), isEmpty);
      expect(DerpService.parseBootstrapDns(''), isEmpty);
    });

    test('JSON 但不是对象时返回空列表', () {
      expect(DerpService.parseBootstrapDns('["a","b"]'), isEmpty);
      expect(DerpService.parseBootstrapDns('null'), isEmpty);
    });

    test('忽略空主机名', () {
      expect(DerpService.parseBootstrapDns('{"":["1.2.3.4"],"ok.example.com":["9.9.9.9"]}'),
          ['ok.example.com']);
    });
  });

  group('sortByLatency', () {
    test('按延迟升序，不可达的排在最后', () {
      final sorted = DerpService.sortByLatency(const [
        DerpProbe(host: 'c', latencyMs: null, error: 'refused'),
        DerpProbe(host: 'a', latencyMs: 42),
        DerpProbe(host: 'b', latencyMs: 7),
        DerpProbe(host: 'd', latencyMs: null),
      ]);
      expect(sorted.map((p) => p.host).toList(), ['b', 'a', 'c', 'd']);
      expect(sorted.first.latencyMs, 7);
      expect(sorted.last.reachable, isFalse);
    });

    test('延迟相同时按主机名稳定排序', () {
      final sorted = DerpService.sortByLatency(const [
        DerpProbe(host: 'z', latencyMs: 20),
        DerpProbe(host: 'a', latencyMs: 20),
      ]);
      expect(sorted.map((p) => p.host).toList(), ['a', 'z']);
    });

    test('空列表不报错', () {
      expect(DerpService.sortByLatency(const []), isEmpty);
    });
  });

  group('DerpProbe', () {
    test('reachable 反映是否有延迟数值', () {
      expect(const DerpProbe(host: 'x', latencyMs: 0).reachable, isTrue);
      expect(const DerpProbe(host: 'x', latencyMs: null).reachable, isFalse);
    });
  });
}
