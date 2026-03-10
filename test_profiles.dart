import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse(
      'https://nenugkyvcewatuddrwvf.supabase.co/rest/v1/profiles?select=id,full_name,is_active,receive_bottles,bottles_received_today,last_active,gender,birth_year&limit=10');
  final request = await HttpClient().getUrl(url);
  request.headers
      .add('apikey', 'sb_publishable_FJpEIk5UxIj73h-qrs99fA_1dlJO0LT');
  request.headers.add(
      'Authorization', 'Bearer sb_publishable_FJpEIk5UxIj73h-qrs99fA_1dlJO0LT');
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  File('test_output.json').writeAsStringSync(responseBody);
}
