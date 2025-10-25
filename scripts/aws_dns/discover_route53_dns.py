#!/usr/bin/env python3
"""
AWS Route53 DNS Server Discovery Tool

Discovers all AWS Route53 nameservers by scanning possible combinations
and resolving them to unique IP addresses.
"""

import asyncio
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, Set, List, Tuple, Optional
import argparse
import json

try:
    import dns.resolver
    import dns.exception
except ImportError:
    print("Error: dnspython library is required", file=sys.stderr)
    print("Install it with: pip3 install dnspython", file=sys.stderr)
    sys.exit(1)


@dataclass
class DNSServer:
    """Represents a DNS server with its hostname and IP addresses."""
    hostname: str
    ips: Set[str]


class RateLimiter:
    """Rate limiter to control queries per second."""

    def __init__(self, rate: int):
        self.rate = rate
        self.tokens = rate
        self.last_update = time.time()
        self.lock = asyncio.Lock()

    async def acquire(self):
        """Acquire a token for making a request."""
        async with self.lock:
            now = time.time()
            elapsed = now - self.last_update
            self.tokens = min(self.rate, self.tokens + elapsed * self.rate)
            self.last_update = now

            if self.tokens < 1:
                sleep_time = (1 - self.tokens) / self.rate
                await asyncio.sleep(sleep_time)
                self.tokens = 0
            else:
                self.tokens -= 1


class Route53Discovery:
    """Main class for discovering AWS Route53 DNS servers."""

    # AWS Route53 TLDs
    TLDS = ['net', 'com', 'org', 'co.uk']

    def __init__(self, qps: int = 25, ns_range: Tuple[int, int] = (0, 9999),
                 awsdns_range: Tuple[int, int] = (0, 99)):
        self.qps = qps
        self.ns_range = ns_range
        self.awsdns_range = awsdns_range
        self.rate_limiter = RateLimiter(qps)

        # Statistics
        self.total_queries = 0
        self.successful_queries = 0
        self.failed_queries = 0
        self.servers: Dict[str, DNSServer] = {}
        self.ip_to_servers: Dict[str, List[str]] = defaultdict(list)

        # Pipeline statistics
        self.apex_zones_checked: Set[str] = set()
        self.apex_zones_valid: Set[str] = set()
        self.no_soa_record = 0
        self.no_a_aaaa_record = 0

        self.start_time = None
        self.lock = asyncio.Lock()

    def generate_apex_zones(self) -> List[str]:
        """Generate all possible AWS Route53 apex zones.

        Format: awsdns-{00-99}.{net,com,org,co.uk}
        Total: 100 * 4 = 400 possible apex zones
        """
        apex_zones = []
        for awsdns_num in range(self.awsdns_range[0], self.awsdns_range[1] + 1):
            for tld in self.TLDS:
                apex_zone = f"awsdns-{awsdns_num:02d}.{tld}"
                apex_zones.append(apex_zone)
        return apex_zones

    def generate_nameservers_for_zone(self, apex_zone: str) -> List[str]:
        """Generate all nameserver hostnames for a given apex zone.

        Example: awsdns-61.net -> [ns-0.awsdns-61.net, ns-1.awsdns-61.net, ...]
        """
        nameservers = []
        for ns_num in range(self.ns_range[0], self.ns_range[1] + 1):
            hostname = f"ns-{ns_num}.{apex_zone}"
            nameservers.append(hostname)
        return nameservers

    async def check_soa_record(self, apex_zone: str) -> bool:
        """Check if apex zone has SOA record."""
        await self.rate_limiter.acquire()

        try:
            loop = asyncio.get_event_loop()
            resolver = dns.resolver.Resolver()
            resolver.timeout = 2
            resolver.lifetime = 2

            # Run DNS query in thread pool
            await loop.run_in_executor(None, resolver.resolve, apex_zone, 'SOA')
            return True
        except (dns.exception.DNSException, Exception):
            return False

    async def resolve_hostname(self, hostname: str) -> Set[str]:
        """Resolve a hostname to its IP addresses using A/AAAA records."""
        await self.rate_limiter.acquire()

        ips = set()

        try:
            loop = asyncio.get_event_loop()
            resolver = dns.resolver.Resolver()
            resolver.timeout = 2
            resolver.lifetime = 2

            # Check A records
            try:
                answers = await loop.run_in_executor(None, resolver.resolve, hostname, 'A')
                for rdata in answers:
                    ips.add(str(rdata))
            except dns.exception.DNSException:
                pass

            # Check AAAA records
            try:
                answers = await loop.run_in_executor(None, resolver.resolve, hostname, 'AAAA')
                for rdata in answers:
                    ips.add(str(rdata))
            except dns.exception.DNSException:
                pass

        except Exception:
            pass

        async with self.lock:
            self.total_queries += 1
            if ips:
                self.successful_queries += 1
            else:
                self.failed_queries += 1

        return ips

    async def validate_apex_zone(self, apex_zone: str) -> bool:
        """Validate a single apex zone by checking for SOA record."""
        has_soa = await self.check_soa_record(apex_zone)

        async with self.lock:
            self.apex_zones_checked.add(apex_zone)
            if has_soa:
                self.apex_zones_valid.add(apex_zone)
                return True
            else:
                self.no_soa_record += 1
                return False

    async def process_nameserver(self, hostname: str):
        """Process a single nameserver hostname - check A/AAAA records."""
        ips = await self.resolve_hostname(hostname)

        if ips:
            async with self.lock:
                self.servers[hostname] = DNSServer(hostname=hostname, ips=ips)
                for ip in ips:
                    self.ip_to_servers[ip].append(hostname)
        else:
            async with self.lock:
                self.no_a_aaaa_record += 1

    async def print_progress(self, total: int):
        """Print progress updates periodically."""
        while True:
            await asyncio.sleep(10)  # Update every 10 seconds
            async with self.lock:
                if self.total_queries >= total:
                    break

                elapsed = time.time() - self.start_time
                rate = self.total_queries / elapsed if elapsed > 0 else 0
                eta = (total - self.total_queries) / rate if rate > 0 else 0

                progress = (self.total_queries / total) * 100
                print(f"\rProgress: {self.total_queries}/{total} ({progress:.2f}%) | "
                      f"Rate: {rate:.2f} qps | ETA: {eta/60:.1f} min | "
                      f"Found: {len(self.servers)} servers",
                      end='', flush=True)

    async def discover(self):
        """Main discovery process.

        Pipeline:
        1. Generate all possible apex zones (awsdns-{00-99}.{tld})
        2. Validate apex zones by checking SOA records
        3. Generate nameservers only for valid apex zones
        4. Check A/AAAA records for nameservers
        """
        self.start_time = time.time()

        # Stage 1: Generate and validate apex zones
        print("=" * 80)
        print("STAGE 1: Validating Apex Zones")
        print("=" * 80)
        apex_zones = self.generate_apex_zones()
        print(f"Total apex zones to validate: {len(apex_zones):,}")
        print(f"Checking SOA records...")

        # Validate all apex zones
        tasks = [self.validate_apex_zone(zone) for zone in apex_zones]
        await asyncio.gather(*tasks)

        print(f"Valid apex zones found: {len(self.apex_zones_valid):,}")
        print(f"Invalid apex zones: {self.no_soa_record:,}")
        print()

        if not self.apex_zones_valid:
            print("No valid apex zones found. Exiting.")
            return

        # Stage 2: Generate nameservers for valid zones
        print("=" * 80)
        print("STAGE 2: Discovering Nameservers")
        print("=" * 80)

        all_nameservers = []
        for apex_zone in sorted(self.apex_zones_valid):
            nameservers = self.generate_nameservers_for_zone(apex_zone)
            all_nameservers.extend(nameservers)

        total = len(all_nameservers)
        print(f"Total nameservers to check: {total:,}")
        print(f"Estimated time: {total / self.qps / 60:.1f} minutes")
        print(f"Rate limit: {self.qps} queries per second")
        print("Press Ctrl+C to stop\n")

        # Create progress task
        progress_task = asyncio.create_task(self.print_progress(total))

        # Process nameservers in batches for better responsiveness
        batch_size = 10000

        try:
            for i in range(0, len(all_nameservers), batch_size):
                batch = all_nameservers[i:i + batch_size]
                tasks = [self.process_nameserver(hostname) for hostname in batch]
                await asyncio.gather(*tasks)
        except asyncio.CancelledError:
            raise
        finally:
            # Cancel progress task
            progress_task.cancel()
            try:
                await progress_task
            except asyncio.CancelledError:
                pass

        print()  # New line after progress

    def generate_report(self) -> str:
        """Generate detailed report of findings."""
        elapsed = time.time() - self.start_time

        # Sort IPs for consistent output
        unique_ips = sorted(self.ip_to_servers.keys())

        # Group servers by TLD
        servers_by_tld = defaultdict(list)
        for hostname in self.servers.keys():
            for tld in self.TLDS:
                if hostname.endswith(f".{tld}"):
                    servers_by_tld[tld].append(hostname)
                    break

        report = []
        report.append("=" * 80)
        report.append("AWS Route53 DNS Server Discovery Report")
        report.append("=" * 80)
        report.append("")

        # Summary
        report.append("SUMMARY")
        report.append("-" * 80)
        report.append(f"Total queries:          {self.total_queries:,}")
        report.append(f"Successful queries:     {self.successful_queries:,}")
        report.append(f"Failed queries:         {self.failed_queries:,}")
        report.append(f"Total servers found:    {len(self.servers):,}")
        report.append(f"Unique IP addresses:    {len(unique_ips):,}")
        report.append(f"Execution time:         {elapsed:.2f} seconds ({elapsed/60:.2f} minutes)")
        report.append(f"Average rate:           {self.total_queries/elapsed:.2f} qps")
        report.append("")

        # Pipeline statistics
        report.append("PIPELINE STATISTICS")
        report.append("-" * 80)
        report.append(f"Apex zones checked:     {len(self.apex_zones_checked):,}")
        report.append(f"Apex zones valid (SOA): {len(self.apex_zones_valid):,}")
        report.append(f"No SOA record:          {self.no_soa_record:,}")
        report.append(f"No A/AAAA record:       {self.no_a_aaaa_record:,}")
        report.append("")

        # Servers by TLD
        report.append("SERVERS BY TLD")
        report.append("-" * 80)
        for tld in self.TLDS:
            count = len(servers_by_tld[tld])
            report.append(f"{tld:10s}: {count:,} servers")
        report.append("")

        # Unique IPs
        report.append("UNIQUE IP ADDRESSES")
        report.append("-" * 80)
        for ip in unique_ips:
            server_count = len(self.ip_to_servers[ip])
            report.append(f"{ip:15s} - {server_count:,} servers")
        report.append("")

        # IP to servers mapping (first 100 for brevity in console)
        report.append("IP TO SERVERS MAPPING (sample)")
        report.append("-" * 80)
        for i, ip in enumerate(unique_ips[:100]):
            servers = self.ip_to_servers[ip]
            report.append(f"\n{ip}:")
            for server in sorted(servers)[:10]:  # Show first 10 servers per IP
                report.append(f"  - {server}")
            if len(servers) > 10:
                report.append(f"  ... and {len(servers) - 10} more")

            if i >= 99 and len(unique_ips) > 100:
                report.append(f"\n... and {len(unique_ips) - 100} more IPs")
                break

        report.append("")
        report.append("=" * 80)

        return "\n".join(report)

    def save_detailed_json(self, filename: str):
        """Save detailed results to JSON file."""
        data = {
            "summary": {
                "total_queries": self.total_queries,
                "successful_queries": self.successful_queries,
                "failed_queries": self.failed_queries,
                "total_servers": len(self.servers),
                "unique_ips": len(self.ip_to_servers),
                "execution_time": time.time() - self.start_time,
            },
            "unique_ips": sorted(self.ip_to_servers.keys()),
            "ip_to_servers": {ip: sorted(servers) for ip, servers in self.ip_to_servers.items()},
            "servers": {hostname: list(server.ips) for hostname, server in self.servers.items()},
        }

        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)

        print(f"Detailed results saved to: {filename}")


async def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Discover AWS Route53 DNS servers',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Full scan with default settings (25 qps)
  %(prog)s

  # Faster scan with higher QPS
  %(prog)s --qps 50

  # Limited range scan for testing
  %(prog)s --ns-range 0 100 --awsdns-range 0 10

  # Save detailed results to JSON
  %(prog)s --output results.json
        """
    )

    parser.add_argument('--qps', type=int, default=25,
                        help='Queries per second (default: 25)')
    parser.add_argument('--ns-range', type=int, nargs=2, default=[0, 9999],
                        metavar=('START', 'END'),
                        help='Range for ns-XXXX (default: 0 9999)')
    parser.add_argument('--awsdns-range', type=int, nargs=2, default=[0, 99],
                        metavar=('START', 'END'),
                        help='Range for awsdns-YY (default: 0 99)')
    parser.add_argument('--output', type=str, default='route53_discovery.json',
                        help='Output JSON file (default: route53_discovery.json)')

    args = parser.parse_args()

    # Validate ranges
    if args.ns_range[0] > args.ns_range[1]:
        print("Error: ns-range START must be <= END", file=sys.stderr)
        sys.exit(1)

    if args.awsdns_range[0] > args.awsdns_range[1]:
        print("Error: awsdns-range START must be <= END", file=sys.stderr)
        sys.exit(1)

    # Create discovery instance
    discovery = Route53Discovery(
        qps=args.qps,
        ns_range=tuple(args.ns_range),
        awsdns_range=tuple(args.awsdns_range)
    )

    try:
        # Run discovery
        await discovery.discover()

        # Generate and print report
        report = discovery.generate_report()
        print(report)

        # Save detailed results
        discovery.save_detailed_json(args.output)

    except (KeyboardInterrupt, asyncio.CancelledError):
        print("\n\nDiscovery interrupted by user")
        print(f"Processed {discovery.total_queries:,} queries")
        print(f"Found {len(discovery.servers):,} servers with {len(discovery.ip_to_servers):,} unique IPs")

        # Still save partial results
        if len(discovery.servers) > 0:
            try:
                discovery.save_detailed_json(args.output)
            except Exception:
                pass

        sys.exit(1)


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(1)
