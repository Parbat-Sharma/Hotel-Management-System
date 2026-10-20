package hotel;

import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.awt.event.*;
import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.net.URL;

public final class reception_tools {
    private reception_tools() { }

    private static final Color GOLD = new Color(212, 175, 55);
    private static final int POPUP_WIDTH = 1000;
    private static final int POPUP_HEIGHT = 700;

    public static void newCustomer() {
        JFrame frame = base("New Customer Check-in", 850, 520);
        JPanel background = new JPanel(null);
        background.setBackground(ui.NAVY);
        frame.setContentPane(background);

        JPanel overlay = new JPanel();
        overlay.setLayout(null);
        overlay.setOpaque(false);
        overlay.setBounds(0, 0, POPUP_WIDTH, POPUP_HEIGHT);
        background.add(overlay);

        JLabel title = new JLabel("NEW CUSTOMER CHECK-IN");
        title.setFont(new Font("Tahoma", Font.BOLD, 28));
        title.setForeground(Color.WHITE);
        title.setHorizontalAlignment(SwingConstants.CENTER);
        title.setBounds(0, 18, POPUP_WIDTH, 45);
        overlay.add(title);

        int labelX = 60, fieldX = 210, labelWidth = 140, fieldWidth = 200, fieldHeight = 32, startY = 80, gap = 45;

        JTextField name = createStyledField(overlay, "Guest Name", labelX, startY, labelWidth, fieldWidth, fieldHeight);
        JTextField phone = createStyledField(overlay, "Phone", labelX, startY + gap, labelWidth, fieldWidth, fieldHeight);
        JTextField email = createStyledField(overlay, "Email", labelX, startY + gap * 2, labelWidth, fieldWidth, fieldHeight);
        JTextField room = createStyledField(overlay, "Room Number", labelX, startY + gap * 3, labelWidth, fieldWidth, fieldHeight);
        JTextField checkOut = createStyledField(overlay, "Check-out Date", labelX, startY + gap * 4, labelWidth, fieldWidth, fieldHeight);
        checkOut.setToolTipText("Format: YYYY-MM-DD (optional)");
        for (JTextField f : new JTextField[]{name, phone, email, room, checkOut}) f.setBackground(ui.NAVY_DARK);
        JLabel dateHint = new JLabel("YYYY-MM-DD (optional)");
        dateHint.setFont(new Font("Tahoma", Font.PLAIN, 12));
        dateHint.setForeground(new Color(220, 220, 220));
        dateHint.setBounds(420, startY + gap * 4, 200, fieldHeight);
        overlay.add(dateHint);

        JButton save = createStyledButton("Confirm Check-in", new Color(37, 99, 235), 210, 350, 150, 42);
        JButton cancel = createStyledButton("Cancel", new Color(100, 116, 139), 370, 350, 150, 42);
        overlay.add(save); overlay.add(cancel);

        save.addActionListener(e -> {
            String roomNum = room.getText().trim();
            if (name.getText().trim().isEmpty() || roomNum.isEmpty()) { warn(frame, "Guest name and room number are required."); return; }
            LocalDate departure;
            try {
                departure = checkOut.getText().trim().isEmpty() ? null : LocalDate.parse(checkOut.getText().trim());
            } catch (DateTimeParseException ex) { warn(frame, "Check-out date must be in YYYY-MM-DD format, e.g. " + LocalDate.now().plusDays(2)); return; }
            if (departure != null && departure.isBefore(LocalDate.now())) { warn(frame, "Check-out date cannot be in the past."); return; }
            // One stored procedure does the room check, the inserts and the room status in a single transaction.
            try (Connection c = hotel_db.connect(); CallableStatement cs = c.prepareCall("{call sp_check_in(?, ?, ?, ?, ?)}")) {
                cs.setString(1, name.getText().trim()); cs.setString(2, phone.getText().trim()); cs.setString(3, email.getText().trim()); cs.setString(4, roomNum);
                if (departure == null) cs.setNull(5, Types.DATE); else cs.setDate(5, Date.valueOf(departure));
                String newId = "";
                try (ResultSet rs = cs.executeQuery()) { if (rs.next()) newId = " Customer ID: " + rs.getInt("customer_id"); }
                JOptionPane.showMessageDialog(frame, "Guest checked in successfully." + newId); frame.dispose();
            } catch (Exception ex) { error(frame, ex); }
        });
        cancel.addActionListener(e -> frame.dispose());
        frame.setVisible(true);
    }

    public static void updateCustomer() {
        Integer customerId = askCustomerId("Enter customer ID to update:", "Update Customer");
        if (customerId == null) return;
        // The customer's newest stay decides the room and whether the room can still be changed.
        try (Connection c = hotel_db.connect(); PreparedStatement find = c.prepareStatement("SELECT name, phone, email, room_number, status FROM v_customer_info WHERE customer_id=? ORDER BY stay_id DESC LIMIT 1")) {
            find.setInt(1, customerId);
            ResultSet rs = find.executeQuery();
            if (!rs.next()) { JOptionPane.showMessageDialog(null, "Customer ID was not found."); return; }
            String oldRoom = rs.getString(4) == null ? "" : rs.getString(4);
            boolean checkedIn = "Checked In".equalsIgnoreCase(rs.getString(5));

            JFrame frame = base("Update Customer Details", 850, 520);
            BackgroundPanel background = new BackgroundPanel("/icon/image.png");
            background.setLayout(null);
            frame.setContentPane(background);

            JPanel overlay = new JPanel();
            overlay.setLayout(null);
            overlay.setOpaque(false);
            overlay.setBounds(0, 0, POPUP_WIDTH, POPUP_HEIGHT);
            background.add(overlay);

            JLabel title = new JLabel("UPDATE CUSTOMER DETAILS");
            title.setFont(new Font("Tahoma", Font.BOLD, 28));
            title.setForeground(Color.WHITE);
            title.setHorizontalAlignment(SwingConstants.CENTER);
            title.setBounds(0, 18, POPUP_WIDTH, 45);
            overlay.add(title);

            int labelX = 60, fieldX = 210, labelWidth = 140, fieldWidth = 200, fieldHeight = 32, startY = 80, gap = 45;

            JTextField name = createStyledField(overlay, "Guest Name", labelX, startY, labelWidth, fieldWidth, fieldHeight);
            name.setText(rs.getString(1));
            JTextField phone = createStyledField(overlay, "Phone Number", labelX, startY + gap, labelWidth, fieldWidth, fieldHeight);
            phone.setText(rs.getString(2));
            JTextField email = createStyledField(overlay, "Email Address", labelX, startY + gap * 2, labelWidth, fieldWidth, fieldHeight);
            email.setText(rs.getString(3));
            JTextField room = createStyledField(overlay, "Room Number", labelX, startY + gap * 3, labelWidth, fieldWidth, fieldHeight);
            room.setText(oldRoom);
            room.setEnabled(checkedIn); // the room can only be changed while the guest is checked in

            JButton save = createStyledButton("Update Details", new Color(37, 99, 235), 210, 350, 150, 42);
            JButton cancel = createStyledButton("Cancel", new Color(100, 116, 139), 370, 350, 150, 42);
            overlay.add(save); overlay.add(cancel);

            save.addActionListener(e -> {
                String newRoom = room.getText().trim();
                if (name.getText().trim().isEmpty() || (checkedIn && newRoom.isEmpty())) { warn(frame, "Guest name and room number are required."); return; }
                // Open a fresh connection: the one used to load the form is already closed by now.
                try (Connection conn = hotel_db.connect()) {
                    // Room first (it is the step that can be refused), then the contact details.
                    if (checkedIn && !newRoom.equals(oldRoom)) {
                        try (CallableStatement move = conn.prepareCall("{call sp_change_room(?, ?)}")) {
                            move.setInt(1, customerId); move.setString(2, newRoom); move.execute();
                        }
                    }
                    try (CallableStatement update = conn.prepareCall("{call sp_update_customer(?, ?, ?, ?)}")) {
                        update.setInt(1, customerId); update.setString(2, name.getText().trim()); update.setString(3, phone.getText().trim()); update.setString(4, email.getText().trim()); update.execute();
                    }
                    JOptionPane.showMessageDialog(frame, "Customer details updated successfully.");
                    frame.dispose();
                } catch (Exception ex) { error(frame, ex); }
            });
            cancel.addActionListener(e -> frame.dispose());
            frame.setVisible(true);
        } catch (Exception e) { error(null, e); }
    }

    public static void roomService() {
        JFrame frame = base("Room Service Order", 850, 520);
        BackgroundPanel background = new BackgroundPanel("/icon/image.png");
        background.setLayout(null);
        frame.setContentPane(background);

        JPanel overlay = new JPanel();
        overlay.setLayout(null);
        overlay.setOpaque(false);
        overlay.setBounds(0, 0, POPUP_WIDTH, POPUP_HEIGHT);
        background.add(overlay);

        JLabel title = new JLabel("ORDER ROOM SERVICE");
        title.setFont(new Font("Tahoma", Font.BOLD, 28));
        title.setForeground(Color.WHITE);
        title.setHorizontalAlignment(SwingConstants.CENTER);
        title.setBounds(0, 18, POPUP_WIDTH, 45);
        overlay.add(title);

        int labelX = 60, fieldX = 210, labelWidth = 140, fieldWidth = 200, fieldHeight = 32, startY = 80, gap = 45;

        JTextField customerId = createStyledField(overlay, "Customer ID", labelX, startY, labelWidth, fieldWidth, fieldHeight);
        JTextField service = createStyledField(overlay, "Service Name", labelX, startY + gap, labelWidth, fieldWidth, fieldHeight);
        JTextField cost = createStyledField(overlay, "Cost", labelX, startY + gap * 2, labelWidth, fieldWidth, fieldHeight);

        JButton save = createStyledButton("Add Order", new Color(37, 99, 235), 210, 350, 150, 42);
        JButton cancel = createStyledButton("Cancel", new Color(100, 116, 139), 370, 350, 150, 42);
        overlay.add(save); overlay.add(cancel);

        save.addActionListener(e -> {
            if (customerId.getText().trim().isEmpty() || service.getText().trim().isEmpty() || cost.getText().trim().isEmpty()) { warn(frame, "All fields are required."); return; }
            int custId; BigDecimal costValue;
            try { custId = Integer.parseInt(customerId.getText().trim()); } catch (NumberFormatException ex) { warn(frame, "Customer ID must be a number."); return; }
            try { costValue = new BigDecimal(cost.getText().trim()); } catch (NumberFormatException ex) { warn(frame, "Cost must be a number."); return; }
            if (costValue.signum() <= 0) { warn(frame, "Cost must be greater than 0."); return; }
            // The procedure finds the guest's active stay and refuses guests who are not checked in.
            try (Connection c = hotel_db.connect(); CallableStatement cs = c.prepareCall("{call sp_add_room_service(?, ?, ?)}")) {
                cs.setInt(1, custId); cs.setString(2, service.getText().trim()); cs.setBigDecimal(3, costValue);
                cs.execute(); JOptionPane.showMessageDialog(frame, "Service order added successfully."); frame.dispose();
            } catch (Exception ex) { error(frame, ex); }
        });
        cancel.addActionListener(e -> frame.dispose());
        frame.setVisible(true);
    }

    // The lists read from views, not from the tables (the front desk has no access to the tables, and the staff view hides pay).
    public static void rooms() { tableWindow("Room Details", "SELECT room_number AS 'Room Number', availability AS 'Availability', price AS 'Price', cleaning_status AS 'Cleaning', bed_type AS 'Bed Type' FROM v_room_info ORDER BY room_number"); }
    public static void customerInfo() { tableWindow("Customer Information", "SELECT customer_id AS 'Customer ID', name AS 'Guest Name', phone AS 'Phone', email AS 'Email', room_number AS 'Room', check_in AS 'Check In', expected_check_out AS 'Expected Check-out', check_out AS 'Checked Out On', status AS 'Status' FROM v_customer_info ORDER BY customer_id DESC, stay_id DESC"); }
    public static void pickupService() { tableWindow("Pick-up Service - Available Drivers", "SELECT name AS 'Driver', car_model AS 'Car', location AS 'Location', availability AS 'Status' FROM v_driver_info ORDER BY availability, name"); }
    public static void departments() { tableWindow("Department / Employee List", "SELECT name AS 'Employee', department AS 'Department', phone AS 'Phone', email AS 'Email' FROM v_employee_directory ORDER BY department, name"); }

    public static void checkOut() {
        Integer customerId = askCustomerId("Enter customer ID to check out:", "Check Out");
        if (customerId == null) return;
        // The procedure closes the stay; a trigger then frees the room and marks it Dirty.
        try (Connection c = hotel_db.connect(); CallableStatement cs = c.prepareCall("{call sp_check_out(?)}")) {
            cs.setInt(1, customerId);
            cs.execute();
            JOptionPane.showMessageDialog(null, "Guest checked out successfully.");
        } catch (Exception e) { error(null, e); }
    }

    public static void generateBill() {
        Integer customerId = askCustomerId("Enter customer ID to generate bill:", "Billing");
        if (customerId == null) return;
        // The procedure builds (or, for a checked-out stay, returns the frozen) invoice and gives two result sets:
        // the header, then the invoice lines. Billing uses the nightly rate recorded at check-in.
        try (Connection c = hotel_db.connect(); CallableStatement cs = c.prepareCall("{call sp_generate_invoice(?)}")) {
            cs.setInt(1, customerId);
            String guestName = "", roomNum = "";
            int days = 1;
            BigDecimal finalTotal = BigDecimal.ZERO;
            StringBuilder lines = new StringBuilder();
            cs.execute();
            try (ResultSet rs = cs.getResultSet()) {
                if (rs.next()) { guestName = rs.getString("guest_name"); roomNum = rs.getString("room_number"); days = rs.getInt("nights"); finalTotal = rs.getBigDecimal("grand_total"); }
            }
            if (cs.getMoreResults()) {
                try (ResultSet rs = cs.getResultSet()) {
                    while (rs.next()) lines.append(String.format("%s%n    %.2f%n", rs.getString("description"), rs.getBigDecimal("amount")));
                }
            }

            JFrame frame = base("Final Invoice", 400, 500);
            JPanel panel = new JPanel();
            panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
            panel.setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
            panel.setBackground(new Color(18, 34, 52));
            JLabel h1 = new JLabel("HOTEL MANAGEMENT SYSTEM");
            h1.setAlignmentX(Component.CENTER_ALIGNMENT);
            h1.setFont(new Font("Serif", Font.BOLD, 20));
            h1.setForeground(new Color(232, 201, 92));
            panel.add(h1);
            panel.add(Box.createRigidArea(new Dimension(0, 20)));
            String billDetails = String.format("Guest: %s\nRoom: %s\nStay: %d days\n--------------------------\n%s--------------------------\nTOTAL AMOUNT: %.2f", guestName, roomNum, days, lines, finalTotal);
            JTextArea textArea = new JTextArea(billDetails);
            textArea.setEditable(false);
            textArea.setFont(new Font("Monospaced", Font.PLAIN, 14));
            textArea.setForeground(Color.WHITE);
            textArea.setBackground(new Color(18, 34, 52));
            textArea.setAlignmentX(Component.CENTER_ALIGNMENT);
            panel.add(textArea);
            JButton printBtn = button("Close", new Color(37, 99, 235));
            printBtn.setAlignmentX(Component.CENTER_ALIGNMENT);
            printBtn.addActionListener(e -> frame.dispose());
            panel.add(Box.createRigidArea(new Dimension(0, 20)));
            panel.add(printBtn);
            frame.add(panel);
            frame.setVisible(true);
        } catch (Exception e) { error(null, e); }
    }

    private static void tableWindow(String title, String query) {
        JFrame frame = base(title, 920, 500); DefaultTableModel model = new DefaultTableModel(); JTable table = new JTable(model); table.setRowHeight(25);
        table.setBackground(new Color(18, 34, 52)); table.setForeground(Color.WHITE); table.setGridColor(new Color(212, 175, 55)); table.setSelectionBackground(new Color(37, 99, 235));
        table.getTableHeader().setBackground(new Color(10, 22, 36)); table.getTableHeader().setForeground(new Color(232, 201, 92));
        try (Connection c = hotel_db.connect(); Statement s = c.createStatement(); ResultSet rs = s.executeQuery(query)) {
            ResultSetMetaData meta = rs.getMetaData(); for (int i = 1; i <= meta.getColumnCount(); i++) model.addColumn(meta.getColumnLabel(i));
            while (rs.next()) { Object[] row = new Object[meta.getColumnCount()]; for (int i = 0; i < row.length; i++) row[i] = rs.getObject(i + 1); model.addRow(row); }
        } catch (Exception e) { error(frame, e); }
        JScrollPane scrollPane = new JScrollPane(table); scrollPane.getViewport().setBackground(new Color(18, 34, 52));
        JPanel content = new JPanel(new BorderLayout(0, 10)); content.setBackground(new Color(18, 34, 52)); content.setBorder(BorderFactory.createEmptyBorder(12, 12, 12, 12)); content.add(scrollPane, BorderLayout.CENTER);
        JButton back = button("Back", new Color(100, 116, 139)); back.addActionListener(e -> frame.dispose()); content.add(back, BorderLayout.SOUTH);
        frame.add(content); frame.setVisible(true);
    }

    private static JFrame base(String title, int width, int height) { JFrame f = new JFrame("Hotel Management System - " + title); f.setSize(POPUP_WIDTH, POPUP_HEIGHT); f.setLocationRelativeTo(null); f.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE); f.setResizable(false); f.getContentPane().setBackground(new Color(18, 34, 52)); return f; }

    private static JTextField createStyledField(JPanel p, String labelText, int lx, int ly, int lw, int fw, int fh) {
        JLabel label = new JLabel(labelText);
        label.setFont(new Font("Tahoma", Font.BOLD, 14));
        label.setForeground(Color.WHITE);
        label.setBounds(lx, ly, lw, fh);
        p.add(label);
        JTextField field = new JTextField();
        field.setFont(new Font("Tahoma", Font.PLAIN, 14));
        field.setForeground(Color.WHITE);
        field.setBackground(Color.BLACK);
        field.setCaretColor(Color.WHITE);
        field.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createLineBorder(GOLD, 2), BorderFactory.createEmptyBorder(3, 8, 3, 8)));
        field.setBounds(210, ly, fw, fh);
        p.add(field);
        return field;
    }

    private static JButton createStyledButton(String text, Color color, int x, int y, int w, int h) {
        JButton b = new JButton(text);
        b.setFont(new Font("Tahoma", Font.BOLD, 14));
        b.setForeground(Color.WHITE);
        b.setBackground(color);
        b.setFocusPainted(false);
        b.setBorder(BorderFactory.createLineBorder(Color.WHITE, 2));
        b.setBounds(x, y, w, h);
        b.setCursor(new Cursor(Cursor.HAND_CURSOR));
        return b;
    }

    /** Asks for a customer ID. Returns null if cancelled or not a number. */
    private static Integer askCustomerId(String message, String title) {
        String id = JOptionPane.showInputDialog(null, message, title, JOptionPane.QUESTION_MESSAGE);
        if (id == null || id.trim().isEmpty()) return null;
        try {
            return Integer.parseInt(id.trim());
        } catch (NumberFormatException e) {
            JOptionPane.showMessageDialog(null, "Customer ID must be a number.", "Hotel Management", JOptionPane.WARNING_MESSAGE);
            return null;
        }
    }

    private static JButton button(String text, Color color) { JButton b = new JButton(text); b.setBackground(color); b.setForeground(Color.WHITE); b.setFocusPainted(false); return b; }
    private static void warn(Component parent, String text) { JOptionPane.showMessageDialog(parent, text, "Hotel Management", JOptionPane.WARNING_MESSAGE); }
    /** A rule raised by the database itself (SQLSTATE 45000, e.g. "Room 101 is not available") is a warning, anything else an error. */
    private static void error(Component parent, Exception e) {
        boolean rule = e instanceof SQLException && "45000".equals(((SQLException) e).getSQLState());
        JOptionPane.showMessageDialog(parent, rule ? e.getMessage() : "Database error: " + e.getMessage(), "Hotel Management", rule ? JOptionPane.WARNING_MESSAGE : JOptionPane.ERROR_MESSAGE);
    }

    /** Uses the shared image cache, so popups open instantly. */
    static class BackgroundPanel extends ui.BackgroundPanel {
        BackgroundPanel(String path) { super(path); }
    }
}
