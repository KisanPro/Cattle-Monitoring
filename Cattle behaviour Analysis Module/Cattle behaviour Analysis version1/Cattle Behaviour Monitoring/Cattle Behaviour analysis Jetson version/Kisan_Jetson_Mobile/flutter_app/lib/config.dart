class AppConfig {
  // Set the public IP or DNS name of your AWS EC2 Relay Server
  static const String ec2ServerUrl = "http://54.235.107.116:8080";
  
  // List of cameras to pull from the EC2 server
  static const List<String> cameras = ["cam1", "cam2", "cam3"];
}
