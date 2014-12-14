/* Copyright 2014 Nicolas Laplante
*
* This file is part of envelope.
*
* envelope is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* envelope is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with envelope. If not, see http://www.gnu.org/licenses/.
*/

namespace Envelope {

    public class Category : Object, Gee.Comparable<Category> {

        public string name { get; set; }
        public string description { get; set; }
        public int @id { get; set; }
        public Category? parent { get; set; default = null; }
        public double amount_budgeted { get; set; default = 0d; }
        public Gee.ArrayList<Transaction> transactions { get; set; }

        public Category () {
            Object ();
        }

        public int compare_to (Category category) {
            return 1;
        }

        public double get_amount_spent (DateTime? from = null, DateTime? to = null) {
            return 0d;
        }
    }
}
