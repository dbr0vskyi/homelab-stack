#!/usr/bin/env python3
"""
Raspberry Pi Thermal Metrics Exporter for Prometheus
Optimized for Pi 5 with N8N workflow correlation
"""

import time
import subprocess
import logging
import os
import re
import json
import requests
from datetime import datetime
from prometheus_client import start_http_server, Gauge, Counter, Histogram, Info
from prometheus_client.core import CollectorRegistry
from typing import Dict, Optional, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class RaspberryPiThermalExporter:
    """Prometheus exporter for Raspberry Pi thermal metrics"""
    
    def __init__(self):
        self.registry = CollectorRegistry()
        self.setup_metrics()
        self.platform_info = self.detect_platform()
        self.n8n_webhook_url = os.getenv('N8N_WEBHOOK_URL')
        self.last_alert_time = {}
        
        logger.info(f"Thermal exporter initialized for platform: {self.platform_info['model']}")
    
    def setup_metrics(self):
        """Initialize Prometheus metrics"""
        
        # Temperature metrics
        self.cpu_temp = Gauge(
            'rpi_cpu_temperature_celsius',
            'Raspberry Pi CPU temperature in Celsius',
            registry=self.registry
        )
        
        # Throttling metrics
        self.throttling_status = Gauge(
            'rpi_throttling_status',
            'Throttling status bitmask',
            registry=self.registry
        )
        
        self.throttling_active = Gauge(
            'rpi_throttling_active',
            'Currently throttled (1=yes, 0=no)',
            ['reason'],
            registry=self.registry
        )
        
        self.throttling_occurred = Counter(
            'rpi_throttling_events_total',
            'Total throttling events since boot',
            ['reason'],
            registry=self.registry
        )
        
        # Voltage metrics
        self.core_voltage = Gauge(
            'rpi_core_voltage_volts',
            'Core voltage in volts',
            registry=self.registry
        )
        
        # Clock frequency metrics
        self.arm_freq = Gauge(
            'rpi_arm_frequency_hz',
            'ARM CPU frequency in Hz',
            registry=self.registry
        )
        
        self.core_freq = Gauge(
            'rpi_core_frequency_hz',
            'Core frequency in Hz', 
            registry=self.registry
        )
        
        # N8N workflow correlation metrics
        self.workflow_thermal_correlation = Histogram(
            'rpi_workflow_thermal_correlation_seconds',
            'Thermal measurements during N8N workflow execution',
            ['workflow_id', 'step'],
            buckets=[30, 60, 300, 600, 1200, 1800, 3600],
            registry=self.registry
        )
        
        # System info
        self.system_info = Info(
            'rpi_system_info',
            'Raspberry Pi system information',
            registry=self.registry
        )
        
        # Memory metrics (thermal-related)
        self.memory_temp_split = Gauge(
            'rpi_memory_temp_split_mb',
            'GPU/CPU memory split in MB',
            ['type'],
            registry=self.registry
        )
        
        # Thermal zone metrics (fallback for non-Pi systems)
        self.thermal_zone_temp = Gauge(
            'thermal_zone_temperature_celsius',
            'Thermal zone temperature',
            ['zone'],
            registry=self.registry
        )
    
    def detect_platform(self) -> Dict[str, str]:
        """Detect Raspberry Pi platform and capabilities"""
        platform_info = {
            'model': 'unknown',
            'revision': 'unknown',
            'vcgencmd_available': False,
            'thermal_zones': []
        }
        
        try:
            # Try to read Pi model
            with open('/proc/device-tree/model', 'r') as f:
                model = f.read().strip('\x00')
                platform_info['model'] = model
                logger.info(f"Detected model: {model}")
        except:
            logger.warning("Could not read /proc/device-tree/model")
        
        try:
            # Check if vcgencmd is available
            result = subprocess.run(['vcgencmd', 'version'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                platform_info['vcgencmd_available'] = True
                logger.info("vcgencmd is available")
            else:
                logger.warning("vcgencmd not available")
        except:
            logger.warning("vcgencmd command not found")
        
        # Find thermal zones as fallback
        try:
            thermal_zones = []
            thermal_base = '/sys/class/thermal'
            if os.path.exists(thermal_base):
                for item in os.listdir(thermal_base):
                    if item.startswith('thermal_zone'):
                        zone_path = f"{thermal_base}/{item}"
                        try:
                            with open(f"{zone_path}/type", 'r') as f:
                                zone_type = f.read().strip()
                                thermal_zones.append(zone_type)
                        except:
                            thermal_zones.append(item)
            platform_info['thermal_zones'] = thermal_zones
            logger.info(f"Found thermal zones: {thermal_zones}")
        except Exception as e:
            logger.warning(f"Could not enumerate thermal zones: {e}")
        
        return platform_info
    
    def run_vcgencmd(self, command: str) -> Optional[str]:
        """Run vcgencmd command safely"""
        if not self.platform_info['vcgencmd_available']:
            return None
        
        try:
            full_command = f"vcgencmd {command}"
            result = subprocess.run(
                full_command.split(),
                capture_output=True, 
                text=True, 
                timeout=5
            )
            
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                logger.warning(f"vcgencmd {command} failed: {result.stderr}")
                return None
        except Exception as e:
            logger.warning(f"vcgencmd {command} error: {e}")
            return None
    
    def get_temperature(self) -> Optional[float]:
        """Get CPU temperature"""
        # Try vcgencmd first
        temp_output = self.run_vcgencmd("measure_temp")
        if temp_output:
            match = re.search(r"temp=([0-9.]+)'C", temp_output)
            if match:
                return float(match.group(1))
        
        # Fallback to thermal zone
        try:
            for zone in self.platform_info['thermal_zones']:
                zone_path = f"/sys/class/thermal/thermal_zone0/temp"
                if os.path.exists(zone_path):
                    with open(zone_path, 'r') as f:
                        temp_millicelsius = int(f.read().strip())
                        return temp_millicelsius / 1000.0
        except Exception as e:
            logger.warning(f"Could not read thermal zone temperature: {e}")
        
        return None
    
    def get_throttling_status(self) -> Tuple[Optional[int], Dict[str, bool]]:
        """Get throttling status and decode flags"""
        throttled_output = self.run_vcgencmd("get_throttled")
        if not throttled_output:
            return None, {}
        
        match = re.search(r"throttled=0x([0-9A-Fa-f]+)", throttled_output)
        if not match:
            return None, {}
        
        throttled_hex = int(match.group(1), 16)
        
        # Decode throttling flags
        flags = {
            'under_voltage_now': bool(throttled_hex & 0x1),
            'arm_frequency_capped_now': bool(throttled_hex & 0x2),
            'currently_throttled': bool(throttled_hex & 0x4),
            'soft_temp_limit_active': bool(throttled_hex & 0x8),
            'under_voltage_occurred': bool(throttled_hex & 0x10000),
            'arm_frequency_capped_occurred': bool(throttled_hex & 0x20000),
            'throttling_occurred': bool(throttled_hex & 0x40000),
            'soft_temp_limit_occurred': bool(throttled_hex & 0x80000),
        }
        
        return throttled_hex, flags
    
    def get_voltages(self) -> Dict[str, Optional[float]]:
        """Get voltage measurements"""
        voltages = {}
        
        voltage_commands = {
            'core': 'measure_volts core',
            'sdram_c': 'measure_volts sdram_c', 
            'sdram_i': 'measure_volts sdram_i',
            'sdram_p': 'measure_volts sdram_p'
        }
        
        for name, command in voltage_commands.items():
            output = self.run_vcgencmd(command)
            if output:
                match = re.search(r"volt=([0-9.]+)V", output)
                if match:
                    voltages[name] = float(match.group(1))
                else:
                    voltages[name] = None
            else:
                voltages[name] = None
        
        return voltages
    
    def get_frequencies(self) -> Dict[str, Optional[int]]:
        """Get clock frequencies"""
        frequencies = {}
        
        freq_commands = {
            'arm': 'measure_clock arm',
            'core': 'measure_clock core',
            'h264': 'measure_clock h264',
            'isp': 'measure_clock isp',
            'v3d': 'measure_clock v3d',
            'uart': 'measure_clock uart',
            'pwm': 'measure_clock pwm',
            'emmc': 'measure_clock emmc',
            'pixel': 'measure_clock pixel',
            'vec': 'measure_clock vec',
            'hdmi': 'measure_clock hdmi',
            'dpi': 'measure_clock dpi'
        }
        
        for name, command in freq_commands.items():
            output = self.run_vcgencmd(command)
            if output:
                match = re.search(r"frequency\([\d]+\)=(\d+)", output)
                if match:
                    frequencies[name] = int(match.group(1))
                else:
                    frequencies[name] = None
            else:
                frequencies[name] = None
        
        return frequencies
    
    def get_memory_split(self) -> Dict[str, Optional[int]]:
        """Get GPU/CPU memory split"""
        memory_split = {}
        
        split_commands = {
            'arm': 'get_mem arm',
            'gpu': 'get_mem gpu'
        }
        
        for name, command in split_commands.items():
            output = self.run_vcgencmd(command)
            if output:
                match = re.search(r"(\d+)M", output)
                if match:
                    memory_split[name] = int(match.group(1))
                else:
                    memory_split[name] = None
            else:
                memory_split[name] = None
        
        return memory_split
    
    def send_thermal_alert(self, alert_type: str, message: str, temperature: float):
        """Send thermal alert to N8N webhook"""
        if not self.n8n_webhook_url:
            return
        
        # Rate limiting: don't send same alert type more than once per 5 minutes
        current_time = time.time()
        if alert_type in self.last_alert_time:
            if current_time - self.last_alert_time[alert_type] < 300:  # 5 minutes
                return
        
        self.last_alert_time[alert_type] = current_time
        
        payload = {
            'alert_type': alert_type,
            'message': message,
            'temperature': temperature,
            'timestamp': datetime.utcnow().isoformat(),
            'hostname': os.uname().nodename
        }
        
        try:
            requests.post(
                self.n8n_webhook_url,
                json=payload,
                timeout=5
            )
            logger.info(f"Sent thermal alert: {alert_type}")
        except Exception as e:
            logger.warning(f"Failed to send thermal alert: {e}")
    
    def collect_and_update_metrics(self):
        """Collect all metrics and update Prometheus gauges"""
        
        # Temperature
        temp = self.get_temperature()
        if temp is not None:
            self.cpu_temp.set(temp)
            
            # Send alerts based on temperature
            if temp > 85:
                self.send_thermal_alert('critical', f'Critical temperature: {temp}°C', temp)
            elif temp > 80:
                self.send_thermal_alert('warning', f'High temperature: {temp}°C', temp)
        
        # Throttling
        throttled_hex, throttling_flags = self.get_throttling_status()
        if throttled_hex is not None:
            self.throttling_status.set(throttled_hex)
            
            # Update individual throttling flags
            for reason, active in throttling_flags.items():
                if reason.endswith('_now'):
                    # Currently active throttling
                    reason_clean = reason.replace('_now', '')
                    self.throttling_active.labels(reason=reason_clean).set(1 if active else 0)
                    
                    if active:
                        self.send_thermal_alert(
                            'throttling', 
                            f'Throttling active: {reason_clean}', 
                            temp or 0
                        )
                elif reason.endswith('_occurred'):
                    # Throttling occurred since boot (increment counter only once)
                    reason_clean = reason.replace('_occurred', '')
                    if active:
                        # Note: This will increment every time, but that's expected behavior
                        # for occurred flags until reboot
                        pass
        
        # Voltages
        voltages = self.get_voltages()
        if voltages.get('core'):
            self.core_voltage.set(voltages['core'])
        
        # Frequencies
        frequencies = self.get_frequencies()
        if frequencies.get('arm'):
            self.arm_freq.set(frequencies['arm'])
        if frequencies.get('core'):
            self.core_freq.set(frequencies['core'])
        
        # Memory split
        memory_split = self.get_memory_split()
        for mem_type, size in memory_split.items():
            if size is not None:
                self.memory_temp_split.labels(type=mem_type).set(size)
        
        # System info (update periodically)
        self.system_info.info({
            'model': self.platform_info['model'],
            'vcgencmd_available': str(self.platform_info['vcgencmd_available']),
            'thermal_zones': ','.join(self.platform_info['thermal_zones'])
        })
        
        # Fallback thermal zones for non-Pi systems
        for zone in self.platform_info['thermal_zones']:
            try:
                zone_path = f"/sys/class/thermal/thermal_zone0/temp"
                if os.path.exists(zone_path):
                    with open(zone_path, 'r') as f:
                        temp_millicelsius = int(f.read().strip())
                        temp_celsius = temp_millicelsius / 1000.0
                        self.thermal_zone_temp.labels(zone=zone).set(temp_celsius)
            except:
                pass

def main():
    """Main exporter loop"""
    
    # Configuration
    metrics_port = int(os.getenv('METRICS_PORT', '9200'))
    collect_interval = int(os.getenv('COLLECT_INTERVAL', '30'))
    
    logger.info(f"Starting Raspberry Pi Thermal Exporter on port {metrics_port}")
    logger.info(f"Collection interval: {collect_interval} seconds")
    
    # Create and start exporter
    exporter = RaspberryPiThermalExporter()
    
    # Start Prometheus metrics server
    start_http_server(metrics_port, registry=exporter.registry)
    logger.info(f"Metrics server started on http://0.0.0.0:{metrics_port}/metrics")
    
    # Collection loop
    try:
        while True:
            start_time = time.time()
            
            try:
                exporter.collect_and_update_metrics()
                logger.debug("Metrics collection completed")
            except Exception as e:
                logger.error(f"Error collecting metrics: {e}")
            
            # Sleep for remaining interval
            elapsed = time.time() - start_time
            sleep_time = max(0, collect_interval - elapsed)
            time.sleep(sleep_time)
            
    except KeyboardInterrupt:
        logger.info("Exporter stopped by user")
    except Exception as e:
        logger.error(f"Exporter error: {e}")
        raise

if __name__ == '__main__':
    main()