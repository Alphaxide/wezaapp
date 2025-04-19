// transaction_analysis_screen.dart
// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:weza/file_picker.dart';
import 'package:weza/storage/storage_provider.dart';
import 'transaction_service.dart';
import 'transaction_model.dart';
import 'models/mpesa_message.dart';

class TransactionAnalysisScreen extends StatefulWidget {
  const TransactionAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<TransactionAnalysisScreen> createState() => _TransactionAnalysisScreenState();
}

class _TransactionAnalysisScreenState extends State<TransactionAnalysisScreen> {
  List<DateTime> _selectedMonths = [];  // For tracking selected months in the chart
  String _selectedTimeFrame = 'Last 6 Months';
  String _selectedCategory = 'All Categories';
  final List<String> _timeFrames = ['Last Month', 'Last 3 Months', 'Last 6 Months', 'Last Year'];
  List<String> _categories = ['All Categories'];
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    
    try {
      // Ensure storage is initialized before loading transactions
      final storage = MessageStorageProvider().getStorage();
      await storage.initialize();
      
      final loaded = await TransactionService.loadTransactions();
      
      if (mounted) {
        setState(() {
          _transactions = loaded;
          _categories = ['All Categories', ..._transactions.map((t) => t.category).toSet().toList()];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading transactions: ${e.toString()}');
      
      // Handle database closed error
      if (e.toString().contains('database is closed') || 
          e.toString().contains('DatabaseException')) {
        
        // Try to reinitialize storage and reload
        try {
          final storageProvider = MessageStorageProvider();
          await storageProvider.closeStorage();
          final storage = storageProvider.getStorage();
          await storage.initialize();
          
          // Try loading transactions again
          final loaded = await TransactionService.loadTransactions();
          
          if (mounted) {
            setState(() {
              _transactions = loaded;
              _categories = ['All Categories', ..._transactions.map((t) => t.category).toSet().toList()];
              _isLoading = false;
            });
          }
        } catch (retryError) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorSnackBar('Database error: ${retryError.toString()}');
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Error loading transactions: ${e.toString()}');
        }
      }
    }
  }


  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _loadTransactions,
          textColor: Colors.white,
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }


  List<Transaction> get _filteredTransactions {
    List<Transaction> filtered = _transactions.where((t) {
      final categoryMatch = _selectedCategory == 'All Categories' || t.category == _selectedCategory;
      return categoryMatch;
    }).toList();

    return TransactionService.filterByTimeFrame(filtered, _selectedTimeFrame);
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: CircularProgressIndicator(
          color: Theme.of(context).primaryColor,
          strokeWidth: 3,
        ),
      ),
    );
  }

Widget _buildAnalysisContent() {
  final filteredTransactions = _filteredTransactions;
  final categoryBreakdown = TransactionService.getCategoryBreakdown(filteredTransactions);
  final monthlySpendingData = TransactionService.getMonthlySpendingData(filteredTransactions);

  // Calculate total spent and received
  final totalSpent = filteredTransactions
      .where((t) => t.type != 'Incoming')
      .fold(0.0, (sum, t) => sum + t.amount);
  final totalReceived = filteredTransactions
      .where((t) => t.type == 'Incoming')
      .fold(0.0, (sum, t) => sum + t.amount);

  return SingleChildScrollView(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderSection(filteredTransactions, totalSpent, totalReceived),
        _buildMonthlySpendingChart(monthlySpendingData),
        // Add the monthly spending table here
        MonthlySpendingTable(
          transactions: filteredTransactions,
          timeFrame: _selectedTimeFrame,
        ),
        _buildCategoryBreakdownChart(categoryBreakdown),
        CategorySpendingTable(
          transactions: filteredTransactions,
          timeFrame: _selectedTimeFrame,
        ),
        _buildRecentTransactions(filteredTransactions),
        SizedBox(height: 80), // Space for the floating action button
      ],
    ),
  );
}

  Widget _buildHeaderSection(List<Transaction> filteredTransactions, double totalSpent, double totalReceived) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row with summary stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCategory == 'All Categories' 
                        ? 'All Transactions' 
                        : _selectedCategory,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'KSh ${NumberFormat('#,###.00').format(totalSpent - totalReceived)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: totalReceived > totalSpent ? Colors.green.shade300 : Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.date_range,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedTimeFrame,
                      dropdownColor: Theme.of(context).primaryColor,
                      underline: Container(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTimeFrame = newValue;
                          });
                        }
                      },
                      items: _timeFrames.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatisticItem(
                title: 'Transactions',
                value: filteredTransactions.length.toString(),
                icon: Icons.receipt_long,
                color: Colors.white,
              ),
              _StatisticItem(
                title: 'Money Out',
                value: 'KSh ${NumberFormat('#,###').format(totalSpent)}',
                icon: Icons.arrow_upward,
                color: Colors.red.shade300,
              ),
              _StatisticItem(
                title: 'Money In',
                value: 'KSh ${NumberFormat('#,###').format(totalReceived)}',
                icon: Icons.arrow_downward,
                color: Colors.green.shade300,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Category filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: Theme.of(context).primaryColor,
              underline: Container(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                }
              },
              items: _categories.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                label: 'Import',
                icon: Icons.upload_file,
                onPressed: () {
                  // Handle import action
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MessageParserScreen(),
                          ),
                        );

                },
              ),
            ],
          ),
        ],
      ),
    );
  }

// Improved Monthly Spending Chart method that shows incoming vs outgoing transactions
// Here's the improved method with fixes for the reported errors

Widget _buildMonthlySpendingChart(Map<DateTime, double> monthlyData) {
  // Track selected months for filtering
  final List<DateTime> selectedMonths = _selectedMonths; // Use class variable to track selections
  final List<DateTime> availableMonths = _filteredTransactions
      .map((t) => DateTime(t.date.year, t.date.month, 1))
      .toSet()
      .toList()
    ..sort((a, b) => a.compareTo(b));
  
  // If no months are explicitly selected, consider all months as selected
  final bool allMonthsSelected = selectedMonths.isEmpty;
  
  // Create separate maps for incoming and outgoing transactions
  final Map<DateTime, double> incomingData = {};
  final Map<DateTime, double> outgoingData = {};

  // Get incoming and outgoing data based on selected timeframe
  for (final transaction in _filteredTransactions) {
    final month = DateTime(transaction.date.year, transaction.date.month, 1);
    
    // Skip if a specific month filter is active and this month isn't selected
    if (!allMonthsSelected && !selectedMonths.contains(month)) {
      continue;
    }
    
    if (transaction.type == 'Incoming') {
      incomingData[month] = (incomingData[month] ?? 0) + transaction.amount;
    } else {
      outgoingData[month] = (outgoingData[month] ?? 0) + transaction.amount;
    }
  }

  // Combine all dates from both datasets
  final allDates = {...monthlyData.keys, ...incomingData.keys, ...outgoingData.keys}
      .where((date) => allMonthsSelected || selectedMonths.contains(date))
      .toList()
      ..sort((a, b) => a.compareTo(b));
  
  // Create spot data for the charts
  final List<FlSpot> totalSpots = [];
  final List<FlSpot> incomingSpots = [];
  final List<FlSpot> outgoingSpots = [];
  
  // Find the minimum value for Y axis (could be negative if expenses > income)
  double minY = 0;
  
  for (int i = 0; i < allDates.length; i++) {
    final date = allDates[i];
    // Add total spending spots (net flow)
    final double incomingAmount = incomingData[date] ?? 0;
    final double outgoingAmount = outgoingData[date] ?? 0;
    final double netAmount = incomingAmount - outgoingAmount;
    
    totalSpots.add(FlSpot(i.toDouble(), netAmount));
    // Add incoming spots
    incomingSpots.add(FlSpot(i.toDouble(), incomingAmount));
    // Add outgoing spots
    outgoingSpots.add(FlSpot(i.toDouble(), outgoingAmount));
    
    // Update minimum Y value if needed
    if (netAmount < minY) {
      minY = netAmount;
    }
  }
  
  // Find the maximum value for the Y-axis scaling
  final allValues = [
    ...incomingData.values, 
    ...outgoingData.values
  ];
  
  final double maxYValue = allValues.isEmpty ? 10.0 : (allValues.reduce((a, b) => a > b ? a : b) * 1.2);
  
  // Add some padding to the minimum Y value
  minY = minY < 0 ? minY * 1.2 : 0;
  
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction Analysis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  _buildMonthSelectorButton(context, availableMonths),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _getChartTitle(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: allDates.isEmpty
                  ? Center(
                      child: Text(
                        'No data available for the selected period',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: Colors.blueGrey.shade800,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((touchedSpot) {
                                final date = allDates[touchedSpot.x.toInt()];
                                String text;
                                Color textColor;
                                
                                if (touchedSpot.barIndex == 0) {
                                  text = 'Net: KSh ${NumberFormat('#,###').format(touchedSpot.y)}';
                                  textColor = Theme.of(context).primaryColor;
                                } else if (touchedSpot.barIndex == 1) {
                                  text = 'Income: KSh ${NumberFormat('#,###').format(touchedSpot.y)}';
                                  textColor = Colors.green;
                                } else {
                                  text = 'Expense: KSh ${NumberFormat('#,###').format(touchedSpot.y)}';
                                  textColor = Colors.red;
                                }
                                
                                return LineTooltipItem(
                                  '${DateFormat('MMM yyyy').format(date)}\n$text',
                                  TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.left,
                                  children: [
                                    TextSpan(
                                      text: '',
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                          handleBuiltInTouches: true,
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: (maxYValue - minY) / 5,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < allDates.length) {
                                  final date = allDates[value.toInt()];
                                  // Use different format based on timeframe
                                  String format = _selectedTimeFrame == 'Last Month' ? 'dd MMM' : 'MMM yy';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat(format).format(date),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (maxYValue - minY) / 5,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : value.toStringAsFixed(0),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        minX: 0,
                        maxX: (allDates.length - 1).toDouble(),
                        minY: minY, // Use calculated minimum Y value
                        maxY: maxYValue,
                        clipData: FlClipData.all(), // This ensures the chart content is clipped to the chart area
                        lineBarsData: [
                          // Net line (total)
                          LineChartBarData(
                            spots: totalSpots,
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.8),
                                Theme.of(context).primaryColor,
                              ],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: false,
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor.withOpacity(0.2),
                                  Theme.of(context).primaryColor.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              // Only fill when y values are positive
                              cutOffY: 0,
                              applyCutOffY: true,
                            ),
                            aboveBarData: minY < 0 ? BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor.withOpacity(0.2),
                                  Theme.of(context).primaryColor.withOpacity(0.0),
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              // Only fill when y values are negative
                              cutOffY: 0,
                              applyCutOffY: true,
                            ) : null,
                          ),
                          // Incoming line
                          LineChartBarData(
                            spots: incomingSpots,
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [
                                Colors.green,
                                Color(0xFF4CAF50),
                              ],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: false,
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.withOpacity(0.2),
                                  Colors.green.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              cutOffY: 0,
                              applyCutOffY: true,
                            ),
                          ),
                          // Outgoing line
                          LineChartBarData(
                            spots: outgoingSpots,
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [
                                Colors.red,
                                Color(0xFFE57373),
                              ],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: false,
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.withOpacity(0.2),
                                  Colors.red.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              cutOffY: 0,
                              applyCutOffY: true,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  color: Theme.of(context).primaryColor,
                  label: 'Net Flow',
                ),
                const SizedBox(width: 24),
                _buildLegendItem(
                  color: Colors.green,
                  label: 'Income',
                ),
                const SizedBox(width: 24),
                _buildLegendItem(
                  color: Colors.red,
                  label: 'Expenses',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
String _getChartTitle() {
  switch (_selectedTimeFrame) {
    case 'Last Month':
      return 'Daily spending for the last month';
    case 'Last 3 Months':
      return 'Monthly spending for the last 3 months';
    case 'Last 6 Months':
      return 'Monthly spending for the last 6 months';
    case 'Last Year':
      return 'Monthly spending for the last year';
    default:
      return 'Monthly spending trend';
  }
}

// Also update the month selector button to use the class variable
Widget _buildMonthSelectorButton(BuildContext context, List<DateTime> availableMonths) {
  return ElevatedButton.icon(
    onPressed: () {
      _showMonthSelectionDialog(context, availableMonths);
    },
    icon: const Icon(Icons.calendar_month, size: 10),
    label: const Text('Select'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

// Update month selection dialog to use class variable
void _showMonthSelectionDialog(BuildContext context, List<DateTime> availableMonths) {
  // Create a temporary list to track selections in the dialog
  final List<DateTime> tempSelected = List.from(_selectedMonths);
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Months'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableMonths.length,
                itemBuilder: (context, index) {
                  final month = availableMonths[index];
                  final isSelected = tempSelected.contains(month);
                  
                  return CheckboxListTile(
                    title: Text(DateFormat('MMMM yyyy').format(month)),
                    value: isSelected,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          tempSelected.add(month);
                        } else {
                          tempSelected.remove(month);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  // Apply the selections
                  _selectedMonths.clear();
                  _selectedMonths.addAll(tempSelected);
                  Navigator.of(context).pop();
                  
                  // Refresh the chart state
                  this.setState(() {});
                },
                child: const Text('Apply'),
              ),
              TextButton(
                onPressed: () {
                  // Clear all selections
                  tempSelected.clear();
                  setState(() {});
                },
                child: const Text('Clear All'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildLegendItem({required Color color, required String label}) {
  return Row(
    children: [
      Container(
        width: 16,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}


  Widget _buildCategoryBreakdownChart(Map<String, double> breakdown) {
    final List<Color> chartColors = [
      Theme.of(context).primaryColor,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.amber,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.blueGrey,
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Category Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: breakdown.isEmpty
                    ? Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          sections: _getPieChartSections(breakdown, chartColors),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              _buildChartLegend(breakdown, chartColors),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _getPieChartSections(Map<String, double> breakdown, List<Color> colors) {
    final totalAmount = breakdown.values.fold(0.0, (sum, value) => sum + value);
    
    List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    
    breakdown.forEach((category, amount) {
      final percentage = (amount / totalAmount) * 100;
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      
      sections.add(
        PieChartSectionData(
          color: color,
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });
    
    return sections;
  }



  Widget _buildChartLegend(Map<String, double> breakdown, List<Color> colors) {
    return Wrap(
      spacing: 16.0,
      runSpacing: 8.0,
      children: breakdown.keys.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final color = colors[index % colors.length];
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              category,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }


  Widget _buildRecentTransactions(List<Transaction> transactions) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              transactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'No transactions found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  : Column(
                      children: transactions.map((transaction) => _buildTransactionTile(transaction)).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    final bool isIncome = transaction.type == 'Incoming';
    final color = isIncome ? Colors.green : Colors.red;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
          ),
          child: Icon(
            TransactionService.getTypeIcon(transaction.type),
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          transaction.recipient,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          DateFormat('MMM dd, yyyy').format(transaction.date),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'KSh ${NumberFormat('#,##0.00').format(transaction.amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                transaction.category,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light gray background
      appBar: AppBar(
        title: const Text(
          'Transaction Analysis',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 22,
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        
      ),
      body: _isLoading ? _buildLoadingIndicator() : _buildAnalysisContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _loadTransactions(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

// Helper widgets
class _StatisticItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatisticItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class CategorySpendingTable extends StatelessWidget {
  final List<Transaction> transactions;
  final String timeFrame;

  const CategorySpendingTable({
    Key? key,
    required this.transactions,
    required this.timeFrame,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get category breakdown
    final Map<String, double> categoryBreakdown = TransactionService.getCategoryBreakdown(transactions);
    
    // Sort categories by amount (descending)
    final sortedEntries = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Calculate total amount
    final double totalAmount = categoryBreakdown.values.fold(0.0, (sum, amount) => sum + amount);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spending by Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        timeFrame,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w400,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Category',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
              // Table rows
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedEntries.length,
                itemBuilder: (context, index) {
                  final entry = sortedEntries[index];
                  final String category = entry.key;
                  final double amount = entry.value;
                  final double percentage = (amount / totalAmount) * 100;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        // Category indicator
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getCategoryColor(context, index),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Category name
                        Expanded(
                          flex: 5,
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Amount
                        Expanded(
                          flex: 3,
                          child: Text(
                            'KSh ${NumberFormat('#,##0.00').format(amount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        // Percentage
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _getCategoryColor(context, index),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  );
                },
              ),
              // Total row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'KSh ${NumberFormat('#,##0.00').format(totalAmount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '100%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(BuildContext context, int index) {
    final List<Color> colors = [
      Theme.of(context).primaryColor,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.amber,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.blueGrey,
    ];
    
    return colors[index % colors.length];
  }
}

// monthly_spending_table.dart

class MonthlySpendingTable extends StatelessWidget {
  final List<Transaction> transactions;
  final String timeFrame;
  
  const MonthlySpendingTable({
    Key? key,
    required this.transactions,
    required this.timeFrame,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Generate monthly spending data
    final monthlyData = _generateMonthlyData();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Spending',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        timeFrame,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Table headers
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Month',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Spent',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Received',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Net',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
              // Table rows
              monthlyData.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'No data available for the selected period',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: monthlyData.length,
                      itemBuilder: (context, index) {
                        final monthData = monthlyData[index];
                        final spent = monthData['spent'] as double;
                        final received = monthData['received'] as double;
                        final net = received - spent;
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                            color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              // Month
                              Expanded(
                                flex: 4,
                                child: Text(
                                  monthData['month'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              // Spent
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'KSh ${NumberFormat('#,##0.00').format(spent)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              // Received
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'KSh ${NumberFormat('#,##0.00').format(received)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              // Net
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'KSh ${NumberFormat('#,##0.00').format(net)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: net >= 0 ? Colors.green : Colors.red,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        );
                      },
                    ),
              // Total row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: _buildTotalRow(context, monthlyData),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, List<Map<String, dynamic>> monthlyData) {
    final totalSpent = monthlyData.fold<double>(
      0.0, (sum, month) => sum + (month['spent'] as double));
    final totalReceived = monthlyData.fold<double>(
      0.0, (sum, month) => sum + (month['received'] as double));
    final totalNet = totalReceived - totalSpent;
    
    return Row(
      children: [
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Text(
            'Total',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'KSh ${NumberFormat('#,##0.00').format(totalSpent)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'KSh ${NumberFormat('#,##0.00').format(totalReceived)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'KSh ${NumberFormat('#,##0.00').format(totalNet)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: totalNet >= 0 ? Colors.green : Colors.red,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  List<Map<String, dynamic>> _generateMonthlyData() {
    // Get the number of months to display based on the selected time frame
    int monthsToDisplay;
    switch (timeFrame) {
      case 'Last Month':
        monthsToDisplay = 1;
        break;
      case 'Last 3 Months':
        monthsToDisplay = 3;
        break;
      case 'Last 6 Months':
        monthsToDisplay = 6;
        break;
      case 'Last Year':
      default:
        monthsToDisplay = 12;
        break;
    }

    // Calculate the start date based on the current date and selected time frame
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - monthsToDisplay + 1, 1);

    // Create a map to store monthly data
    final Map<String, Map<String, dynamic>> monthlyMap = {};

    // Initialize the map with all months in the range
    for (int i = 0; i < monthsToDisplay; i++) {
      final month = DateTime(startDate.year, startDate.month + i, 1);
      final monthKey = DateFormat('MMMM yyyy').format(month);
      
      monthlyMap[monthKey] = {
        'month': monthKey,
        'spent': 0.0,
        'received': 0.0,
        'date': month, // Keep date for sorting
      };
    }

    // Process transactions
    for (final transaction in transactions) {
      // Check if the transaction falls within our date range
      if (transaction.date.isBefore(startDate)) {
        continue;
      }

      // Get the month key for this transaction
      final monthKey = DateFormat('MMMM yyyy').format(
        DateTime(transaction.date.year, transaction.date.month, 1)
      );

      // Skip if the month isn't in our display range
      if (!monthlyMap.containsKey(monthKey)) {
        continue;
      }

      // Update the appropriate amount
      if (transaction.type == 'Incoming') {
        monthlyMap[monthKey]!['received'] = 
          (monthlyMap[monthKey]!['received'] as double) + transaction.amount;
      } else {
        monthlyMap[monthKey]!['spent'] = 
          (monthlyMap[monthKey]!['spent'] as double) + transaction.amount;
      }
    }

    // Convert map to list and sort by date
    final result = monthlyMap.values.toList()
      ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return result;
  }
}