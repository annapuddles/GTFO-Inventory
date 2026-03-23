// GTFO! Inventory v0.1.0
//
// Tracks GTFO deliveries and pickups and optionally consumes specified types of cargo over time.

// CONFIGURATION

// Inventory configuration settings
//
// Format: name, max, consumption, byproduct
//
// name
//  The GTFO cargo name.
//
// max
//  The maximum amount of the cargo that can be stored.
//  -1 means no maximum.
//
// consumption
//  The number of units consumed per hour.
//  0 means the item is not consumed.
//
// byproduct
//  When units are consumed, add the same amount of units of this cargo type to
//  the inventory. Use an empty string for no byproduct.
list inventory_config = [
    "Food Delivery (Catered)", 100, 1, "",
    "Fuel Cells (Aether)", 100, 0, "Empty Fuel Cells",
    "Fuel Cells (He-3)", 100, 2, "Empty Fuel Cells",
    "Class-A Freight", 100, 2, "",
    "Spare Parts Kits", 100, 0, "",
    "SuperChewy Candy", 100, 2, "",
    "Duct Tape", 100, 1, "",
    "Empty Fuel Cells", -1, 0, "",
    "Priority Freight", -1, 0, "",
    "Subscription Gachas", -1, 0, "",
    "Artisanal Toilet Paper", -1, 0, "",
    "Offshelf Spare Parts", 100, 1, "",
    "Chilled Wine", -1, 0, "",
    "Two-for-one Rubber Chickens", -1, 0, "",
    "The Business", -1, 0, "",
    "Compacted Barrels", -1, 0, "",
    "Fabricator Stock (Alloy)", -1, 0, "",
    "Non-Redundant Spares", 100, 2, ""
];

// Number of elements for each entry in the inventory config list
integer inventory_config_stride = 4;

// The UUID of the Gentek text display board
key inventory_board = "450d5236-3e4d-38cb-6923-7ad2f2966937";

// The channel used to communicate with the display board
integer inventory_board_channel = -495310229;

// How often to progress the board
float update_interval = 20;

// The max number of pages of inventory to show on the board
integer max_pages = 6;

// Show all inventory on the board or only consumables?
integer show_all_inventory = FALSE;

// Rate in hours at which consumption occurs
integer consume_rate = 4;

// For certain vehicles, multiply the amount of cargo added/removed.
// This is because GTFO messages only report the number of containers
// loaded/unloaded, not the amount of FU (freight units), so some vehicles
// would be disadvantaged if they have fewer, larger containers.
list vehicle_multipliers = [
    "SA - Erickson S-64", "2cb70efb-e393-4f15-a7ab-599ed9b43046", 28,
    "SA - Chinook", "2cb70efb-e393-4f15-a7ab-599ed9b43046", 6,
    "SA/VSD - S58", "2cb70efb-e393-4f15-a7ab-599ed9b43046", 2
];

// END OF CONFIGURATION

// Channel for GTFO messages
integer gtfo_channel = -9600;
// Key of the creator of the GTFO HUD
key gtfo_creator = "73973cb4-504f-4cd9-bade-3033d622ecd4";

// The current inventory
list inventory;

// Unix time of last update
integer last_update;

// The current page of the display board
integer inventory_board_page = 0;

// Save the inventory daata to the linkset
save_inventory()
{
    llLinksetDataWrite("gtfo:inventory", llList2Json(JSON_ARRAY, inventory));
    llLinksetDataWrite("gtfo:lastUpdate", (string) last_update);
}

// Load the inventory data from the linkset
load_inventory()
{
    inventory = llJson2List(llLinksetDataRead("gtfo:inventory"));
    last_update = (integer) llLinksetDataRead("gtfo:lastUpdate");

    // Sanitize the inventory based on the current config
    integer n;
    for (n = llGetListLength(inventory) - 2; n >= 0; n -= 2)
    {
        string name = llList2String(inventory, n);
        integer amount = llList2Integer(inventory, n + 1);
        integer inventory_config_index = llListFindStrided(inventory_config, [name], 0, -1, inventory_config_stride);
        if (inventory_config_index != -1)
        {
            integer max = llList2Integer(inventory_config, inventory_config_index + 1);
            
            if (max > -1 && amount > max)
            {
                inventory = llListReplaceList(inventory, [max], n + 1, n + 1);
            }
        }
    }

    save_inventory();
}

// Check whether a GTFO message has come from a real GTFO HUD
integer is_legit_GTFO_HUD(key id)
{
    list details = llGetObjectDetails(id, [OBJECT_CREATOR]);
    key creator = llList2Key(details, 0);
    return creator == gtfo_creator;
}

// Format text for the Gentek text board
string align(string in, string dir, integer length, string pad)
{
    if (pad == "") pad = " ";
    if (llToUpper(dir) == "L")
    {
        while (llStringLength(in) < length)
        {
            in = in + pad;
        }
    }
    else if (llToUpper(dir) == "R")
    {
        while (llStringLength(in) < length)
        {
            in = pad + in;
        }
    }
    else // assume center
    {
        integer osc = 0; // we have to be a little smarter here
        while (llStringLength(in) < length)
        {
            if (osc) in = pad + in; // this will align left, then right,
            else in = in + pad;     // then left, then right...
            osc = !osc;             // ... effectively centering the text
        }
    }
    return llGetSubString(in, 0, length - 1); // cut off any excess if we added it on accident
}

// Add the necessary Gentek formatting to a list of text slides
string gentek_format(list slide_data, list slide_times)
{
    return llDumpList2String(slide_data, "|") + "#$" + llDumpList2String(slide_times, "|");
}

// Get the current inventory data. When all == TRUE, return data for all items, not just consumables.
list get_inventory_data(integer all)
{
    list inv;
    integer n;

    for (n = llGetListLength(inventory_config) - inventory_config_stride; n >= 0; n -= inventory_config_stride)
    {
        string name = llList2String(inventory_config, n);
        integer max = llList2Integer(inventory_config, n + 1);
        integer consume = llList2Integer(inventory_config, n + 2);

        integer amount;
        integer index = llListFindStrided(inventory, [name], 0, -1, 2);
        if (index != -1)
        {
            amount = llList2Integer(inventory, index + 1);
        }
        else
        {
            amount = 0;
        }

        if (consume > 0)
        {
            float hours = ((float) amount / consume) * consume_rate;
            inv += [name, amount, max, hours];
        }
        else if (all && amount > 0)
        {
            inv += [name, amount, max, 9999999.0];
        }
    }
    
    if (all)
    {
        for (n = llGetListLength(inventory) - 2; n >= 0; n -= 2)
        {
            string name = llList2String(inventory, n);
    
            if (llListFindStrided(inv, [name], 0, -1, 4) == -1)
            {
                integer amount = llList2Integer(inventory, n + 1);
    
                integer index = llListFindStrided(inventory_config, [name], 0, -1, inventory_config_stride);
                if (index != -1)
                {
                    integer max = llList2Integer(inventory_config, index + 1);
                    integer consume = llList2Integer(inventory_config, index + 2);
    
                    if (consume > 0)
                    {
                        float hours = ((float) amount / consume) * consume_rate;
                        inv += [name, amount, max, hours];
                    }
                    else if (amount > 0)
                    {
                        inv += [name, amount, max, 9999999.0];
                    }
                }
                else if (amount > 0)
                {
                    inv += [name, amount, -1, 9999999.0];
                }
            }
        }
    }

    return llListSortStrided(inv, 4, 1, TRUE);
}

// Add an amount of some cargo to the inventory
add_inventory(string cargo_name, integer cargo_amount)
{
    integer inventory_index = llListFindStrided(inventory, [cargo_name], 0, -1, 2);
    if (inventory_index == -1)
    {
        inventory += [cargo_name, cargo_amount];
    }
    else
    {
        integer amount = llList2Integer(inventory, inventory_index + 1);
        
        integer max;
        integer inventory_config_index = llListFindStrided(inventory_config, [cargo_name], 0, -1, inventory_config_stride);
        if (inventory_config_index == -1)
        {
            max = -1;
        }
        else
        {
            max = llList2Integer(inventory_config, inventory_config_index + 1);
        }
        
        amount += cargo_amount;
        if (max > -1 && amount > max)
        {
            amount = max;
        }
        
        inventory = llListReplaceList(inventory, [amount], inventory_index + 1, inventory_index + 1);
    }
    
    save_inventory();
    
    update_inventory_board();
}

// Remove some amount of some cargo from the inventory
remove_inventory(string cargo_name, integer cargo_amount)
{
    integer inventory_index = llListFindStrided(inventory, [cargo_name], 0, -1, 2);
    if (inventory_index != -1)
    {
        integer amount = llList2Integer(inventory, inventory_index + 1);
        amount -= cargo_amount;
        if (amount <= 0)
        {
            inventory = llDeleteSubList(inventory, inventory_index, inventory_index + 1);
        }
        else
        {
            inventory = llListReplaceList(inventory, [amount], inventory_index + 1, inventory_index + 1);
        }
        
        save_inventory();
        
        update_inventory_board();
    }
}

// Perform an update of the text on the Gentek display
update_inventory_board()
{
    string data = align("GTFO! INVENTORY", "", 32, "");
    list inv = get_inventory_data(show_all_inventory);

    integer total_pages = llCeil(llGetListLength(inv) / 16.0);
    if (total_pages > max_pages)
    {
        total_pages = max_pages;
    }
    
    if (inventory_board_page == -1)
    {
        data +=
            align("", "", 32, "") +
            align("RED     RUNS OUT IN < 24 HOURS", "L", 32, "") +
            align("ORANGE  RUNS OUT IN < 72 HOURS", "L", 32, "") +
            align("GREEN   RUNS OUT IN < 1 WEEK", "L", 32, "") +
            align("BLUE    EXPORTABLE GOODS", "L", 32, "") +
            align("", "", 32, "W") +
            align("", "", 32, "W") +
            align("", "", 8, "R") + align("", "", 24, "W") +
            align("", "", 8, "O") + align("", "", 24, "W") +
            align("", "", 8, "G") + align("", "", 24, "W") +
            align("", "", 8, "B") + align("", "", 24, "W");
    }
    else
    {
        if (total_pages > 1)
        {
            data += align("QTY/MAX ITEM            PAGE " + (string) (inventory_board_page + 1) + "/" + format_num(total_pages, 1), "L", 32, "");
        }
        else
        {
            data += align("QTY/MAX ITEM", "L", 32, "");
        }
        
        inv = llListSortStrided(inv, 4, 3, TRUE);

        integer len = llGetListLength(inv);
        integer s = inventory_board_page * 16;
        integer e = s + 16;
        if (e > len)
        {
            e = len;
        }

        list colors;
        integer n;
        integer i;

        for (n = s; n < e; n += 4)
        {
            string name = llList2String(inv, n);
            integer amount = llList2Integer(inv, n + 1);
            integer max = llList2Integer(inv, n + 2);
            float hours = llList2Float(inv, n + 3);

            name = llToUpper(llGetSubString(name, 0, 24));
            
            if (max == -1)
            {
                data += align(align(format_num(amount, 3), "R", 3, "") + "/--- " + name, "L", 32, "");
            }
            else
            {
                data += align(align(format_num(amount, 3), "R", 3, "") + "/" + align(format_num(max, 3), "R", 3, "") + " " + name, "L", 32, "");
            }
            if (hours <= 24)
            {
                colors += "R";
            }
            else if (hours <= 72)
            {
                colors += "O";
            }
            else if (hours <= 168)
            {
                colors += "G";
            }
            else
            {
                colors += "B";
            }
            ++i;
        }
        for (; i < 4; ++i)
        {
            data += align("", "", 32, "");
        }

        data += 
            align("", "", 32, "W") +
            align("", "", 24, "A") + align("", "", 8, "P") +
            align("", "", 8, llList2String(colors, 0)) + align("", "", 24, "W") +
            align("", "", 8, llList2String(colors, 1)) + align("", "", 24, "W") +
            align("", "", 8, llList2String(colors, 2)) + align("", "", 24, "W") +
            align("", "", 8, llList2String(colors, 3)) + align("", "", 24, "W");
    }

    llRegionSayTo(inventory_board, inventory_board_channel, gentek_format([data], []));

    ++inventory_board_page;
    if (inventory_board_page == total_pages)
    {
        inventory_board_page = 0;
    }
}

// Pad a number with a specified amount of digits
string format_num(integer n, integer digits)
{
    string s = (string) n;
    if (llStringLength(s) > digits)
    {
        return align("", "", digits, "9");
    }
    else
    {
        return s;
    }
}

// Determine the cargo multipler for the vehicle delivering or picking up
integer get_vehicle_multiplier(key id)
{
    key owner = llGetOwnerKey(id);
    key root = llList2Key(llGetObjectDetails(owner, [OBJECT_ROOT]), 0);
    list details = llGetObjectDetails(root, [OBJECT_NAME, OBJECT_CREATOR]);
    string root_name = llList2String(details, 0);
    key root_creator = llList2Key(details, 1);
        
    integer n;
    for (n = llGetListLength(vehicle_multipliers) - 3; n >= 0; n -= 3)
    {
        string prefix = llList2String(vehicle_multipliers, n);
        key creator = llList2Key(vehicle_multipliers, n + 1);
        integer mult = llList2Integer(vehicle_multipliers, n + 2);
        
        if (llGetSubString(root_name, 0, llStringLength(prefix) - 1) == prefix && root_creator == creator)
        {
            return mult;
        }
    }
    
    return 1;
}

/* The following functions are taken from
 * https://github.com/annapuddles/jsonrpc-sl and are used to create and send
 * JSON-RPC notifications via link message.
 */
string jsonrpc_notification(string method, string params_type, list params)
{
    return llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "method", method, "params", llList2Json(params_type, params)]);
}

jsonrpc_link_notification(integer link, string method, string params_type, list params)
{
    llMessageLinked(link, 0, jsonrpc_notification(method, params_type, params), NULL_KEY);
}

default
{
    state_entry()
    {
        load_inventory();

        llListen(gtfo_channel, "", "", "");
        
        update_inventory_board();
        llSetTimerEvent(update_interval);
    }

    listen(integer channel, string name, key id, string message)
    {
        // Check that the sender is a legitimate GTFO HUD
        if (!is_legit_GTFO_HUD(id))
        {
            return;
        }
        
        integer mult = get_vehicle_multiplier(id);
                
        integer index;

        // Picked up cargo
        if ((index = llSubStringIndex(message, " picked up ")) != -1)
        {
            string cargo = llGetSubString(message, index + 11, -1);
            integer separator = llSubStringIndex(cargo, " ");
            integer cargo_amount = (integer) llGetSubString(cargo, 0, separator - 1);
            string cargo_name = llGetSubString(cargo, separator + 1, -1);

            remove_inventory(cargo_name, cargo_amount * mult);
        }
        // Unloaded cargo
        else if ((index = llSubStringIndex(message, " unloaded ")) != -1)
        {
            string cargo = llGetSubString(message, index + 10, -1);
            integer separator = llSubStringIndex(cargo, " ");
            integer cargo_amount = (integer) llGetSubString(cargo, 0, separator - 1);
            string cargo_name = llGetSubString(cargo, separator + 1, -1);
            
            add_inventory(cargo_name, cargo_amount * mult);
        }
    }
    
    timer()
    {
        integer time = llGetUnixTime();
        
        // Apply consumption rates to current inventory every consume_rate hours
        if (time - last_update >= consume_rate * 3600)
        {
            integer n;
            for (n = llGetListLength(inventory) - 2; n >= 0; n -= 2)
            {
                string name = llList2String(inventory, n);
                integer amount = llList2Integer(inventory, n + 1);
                
                integer index = llListFindStrided(inventory_config, [name], 0, -1, inventory_config_stride);
                if (index != -1)
                {
                    integer consume = llList2Integer(inventory_config, index + 2);
                    
                    if (consume > 0 && amount > 0)
                    {
                        if (consume > amount)
                        {
                            consume = amount;
                        }
                                                
                        inventory = llListReplaceList(inventory, [amount - consume], n + 1, n + 1);
                        
                        string byproduct = llList2String(inventory_config, index + 3);
                        if (byproduct != "")
                        {
                            add_inventory(byproduct, consume);
                        }
                    }
                }
            }
            
            last_update = time;
            
            save_inventory();
        }
        
        update_inventory_board();
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        string jsonrpc_method = llJsonGetValue(str, ["method"]);
        
        if (jsonrpc_method == "prim-dns:startup")
        {
            jsonrpc_link_notification(LINK_SET, "prim-dns:file-server:register-path", JSON_OBJECT, ["path", "/inventory.json"]);
        }
        else if (jsonrpc_method == "prim-dns:request")
        {
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            string headers = llJsonGetValue(str, ["params", "headers"]);
            string path = llJsonGetValue(headers, ["x-path-info"]);
            
            if (path == "/inventory.json")
            {
                list inv = llListSortStrided(get_inventory_data(TRUE), 4, 3, FALSE);
                list data;
                integer n;
                for (n = llGetListLength(inv) - 4; n >= 0; n -= 4)
                {
                    data += llList2Json(JSON_OBJECT, [
                        "name", llList2String(inv, n),
                        "amount", llList2Integer(inv, n + 1),
                        "max", llList2Integer(inv, n + 2),
                        "hours", llList2Float(inv, n + 3)
                    ]);
                }
                
                jsonrpc_link_notification(sender, "prim-dns:set-content-type", JSON_OBJECT, [
                    "request-id",request_id,
                    "content-type", CONTENT_TYPE_JSON
                ]);
                jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, [
                    "request-id", request_id,
                    "status", 200,
                    "body", llList2Json(JSON_ARRAY, data)
                ]);
            }
        }
    }
}
