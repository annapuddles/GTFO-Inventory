# GTFO! Inventory

GTFO! Inventory is an inventory system for the GTFO! cargo delivery game on Second Life.

# Features

- Tracks deliveries and pickups at your GTFO! hub and records how much stock you have of each item
- Items can be set to be consumed over time, which provides a reason to restock your hub regularly
- Items can create byproducts when consumed which are added to your inventory and should be taken away
- Stock levels can be displayed on a [GenTek text board](https://marketplace.secondlife.com/p/InfoCenter-Display-Kit-Four-Electronic-Text-Display-Sign-Models/6579929) and/or a web interface (with [prim-dns](https://github.com/annapuddles/prim-dns-server))

# Setup

Rez the `GTFO! Inventory server` object at your GTFO! hub.

# Configuration

The configuration is split into three notecards:

## GTFO! Inventory settings

This notecard contains the general settings for the inventory system.

Each line is formatted as:

```
name = value
```

The spaces around the `=` are mandatory.

| Setting | Description |
|-|-|
| `inventory_board` | The key of the GenTek text board that stock will be displayed on. |
| `inventory_board_channel` | The channel number used to communicate with the GenTek text board. |
| `update_interval` | How often in seconds to progress the text board. |
| `max_pages` | The max number of pages of stock that will be displayed on the board. |
| `show_all_inventory` | Whether to show all inventory on the text board or only items that are consumed. |
| `consume_rate` | The rate in hours at which consumption of items occurs. |

## GTFO! Inventory items

This notecard contains the settings for each GTFO! item that can be delivered to or picked up from your hub.

Each line is formatted as:

```
item name|max|consumption|byproduct
```

| Field         | Description |
|---------------|-------------|
| `item name`   | The name of the GTFO! item. |
| `max`         | The maximum stock level for the item. Once this level is reached, further deliveries of this item are ignored. A value of `-1` means there is no maximum limit. |
| `consumption` | How much stock of this item is consumed at the configured consumption rate in hours. A value of `0` means the item will not be consumed over time. |
| `byproduct`   | The name of a GTFO! item that is a byproduct of consuming this item. If specified, when the item is consumed, the same amount of stock of the byproduct item will be added to your inventory. An empty string means there is no byproduct for the item. |

## GTFO! Inventory multipliers

This notecard allows you to specify multipliers to stock levels delivered/picked up based on the vehicle the avatar is using.

Each line is formatted as:

```
name prefix|creator key|multiplier
```

| Field         | Description                                       |
|---------------|---------------------------------------------------|
| `name prefix` | A prefix that the vehicle's name must start with. |
| `creator key` | The UUID of the creator of the vehicle.           |
| `multiplier`  | The number to multiply the amount of stock by.    |

# Activating the web interface

Once rezzed, the `GTFO! Inventory server` will already be tracking GTFO! deliveries and pickups, but to enable the web interface you must do the following:

1. Click on the `GTFO! Inventory server` object at your hub.
2. Click the `power on` button to start the prim-dns server.
3. Copy the auth key in chat into `prim-dns config` notecard, placing it on the line after `auth = `.

You can then access the web interface on the built-in media screen, or at `https://annapuddles.com/prim-dns/redirect/<uuid>`, where `<uuid>` is the UUID of the `GTFO! Inventory server` object.

If desired, you can set a custom alias for your web interface instead of the object's UUID by modifying the `prim-dns config` notecard.

# Connecting to the GenTek textboard

1. Rez the GenTek text board.
2. Set the channel number in the board's settings.
3. Copy the UUID of the board and the channel number into the `GTFO! Inventory settings` notecard.
4. Reset the `GTFO! Inventory` script.
