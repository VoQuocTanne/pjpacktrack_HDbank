import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'order_process_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('Chưa đăng nhập'));
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Lịch sử đơn hàng',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal,
          elevation: 0,
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('userId', isEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final allDocs = snapshot.data?.docs ?? [];

              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allDocs.length,
                  itemBuilder: (context, index) {
                    final doc = allDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isQRCode = data['isQRCode'] ?? false;

                    return _buildOrderCard(
                        doc.id, data, isQRCode, context, currentUser.uid);
                  });
            }));
  }

  Widget _buildOrderCard(String docId, Map<String, dynamic> data, bool isQRCode,
      BuildContext context, String userId) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () =>
            _navigateToOrderProcess(context, data, docId, isQRCode, userId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderHeader(docId, data, isQRCode),
              const Divider(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(
      String docId, Map<String, dynamic> data, bool isQRCode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isQRCode ? "Mã đơn hàng" : "Mã đơn hàng"}: $docId',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusChips(data),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChips(Map<String, dynamic> data) {
    return Wrap(
      spacing: 8,
      children: [
        if (data['closedStatus'] == true)
          _buildStatusChip('Đóng gói', Colors.blue),
        if (data['shippingStatus'] == true)
          _buildStatusChip('Giao hàng', Colors.green),
        if (data['returnStatus'] == true)
          _buildStatusChip('Trả hàng', Colors.orange),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
    );
  }

  void _navigateToOrderProcess(BuildContext context, Map<String, dynamic> data,
      String docId, bool isQRCode, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderProcessScreen(
          orderData: {
            ...data,
            'id': docId,
            'isQRCode': isQRCode,
          },
          videoData: {},
          orderDate: DateTime.now().toString(),
          userId: userId,
        ),
      ),
    );
  }
}
