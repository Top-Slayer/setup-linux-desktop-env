use std::{fs, process::Command, thread, time::Duration};
use chrono::Local;

fn set_status_bar() {

}

fn main() {
    loop {
        let battery_percent = fs::read_to_string("/sys/class/power_supply/BAT1/capacity")
            .unwrap_or_else(|_| "N/A".to_string());
        let battery_status = fs::read_to_string("/sys/class/power_supply/BAT1/status")
            .unwrap_or_else(|_| "N/A".to_string());
        let date_time = Local::now().format("%d-%m-%Y %I:%M:%S %p").to_string();
        let status_bar = format!("BAT {}% {} | {}",battery_percent.trim(), battery_status.trim(), date_time);

        Command::new("xsetroot")
            .arg("-name")
            .arg(&status_bar)
            .status()
            .unwrap();

        thread::sleep(Duration::from_secs(1)); 
    }
}
