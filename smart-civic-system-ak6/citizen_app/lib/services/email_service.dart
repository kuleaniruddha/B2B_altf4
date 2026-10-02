import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  /// Sends the complaint confirmation PDF to the user's registered email.
  /// NOTE: For production, IT IS RECOMMENDED to handle this via Cloud Functions.
  static Future<bool> sendComplaintConfirmation(File pdf, String recipientEmail, String trackId) async {
    // ── CONFIGURATION ────────────────────────────────────────────────────────
    // Replace these with your actual SMTP credentials (e.g., Gmail App Password)
    // For Gmail: use 'smtp.gmail.com', port 465 (SSL) or 587 (TLS)
    const String smtpHost = 'smtp.gmail.com'; 
    const int smtpPort = 465;
    const String username = 'aniruddhakule@gmail.com';
    const String password = 'qnjc epse obpp geet';
    // ──────────────────────────────────────────────────────────────────────────

    if (username.contains('YOUR_EMAIL')) {
      print("EmailService: SMTP Credentials not configured correctly.");
      return false;
    }

    final smtpServer = gmail(username, password);

    // Create the message
    final message = Message()
      ..from = Address(username, 'BMC Smart Civic')
      ..recipients.add(recipientEmail)
      ..subject = 'Complaint Confirmation: $trackId'
      ..text = 'Hello,\n\nYour civic complaint has been successfully registered. Please find the attached confirmation report for your records.\n\nTracking ID: $trackId\n\nThank you for helping us make Mumbai better.'
      ..attachments.add(FileAttachment(pdf));

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
      return true;
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }
}
