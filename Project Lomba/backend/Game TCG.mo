import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Random "mo:base/Random";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Debug "mo:base/Debug";

actor Game {

    // =====================================================================
    // TIPE DATA KUSTOM
    // =====================================================================

    type Role = {
        #Swordman;
        #Archer;
        #Mage;
        #Priest;
        #Berserker;
        #Tank;
        #Assassin;
        #Beast;
        #Dragon;
        #Undead;
        #Mythical;
    };

    type Item = {
        name: Text;
        desc: Text;
    };

    // Kelas untuk Kartu
    class Kartu(name: Text, role: Role, hp: Nat, attack: Nat, defense: Nat) {
        public var name: Text = name;
        public var role: Role = role;
        public var max_hp: Nat = hp;
        public var hp: Nat = hp;
        public var attack: Nat = attack;
        public var defense: Nat = defense;
        public var max_energy: Nat = 100;
        public var energy: Nat = 0;
        public var def_down: Bool = false;

        public func is_alive(): Bool {
            return self.hp > 0;
        };

        public func take_damage(amount: Nat) {
            let effective_def = self.def_down ? self.defense / 2 : self.defense;
            let damage = if (amount > effective_def) amount - effective_def else 1;
            self.hp -= damage;
            Debug.print(debug_show(self.name) # " menerima " # Nat.toText(damage) # " damage! (Sisa HP: " # Nat.toText(self.hp) # ")");
            if (self.hp < 0) {
                self.hp := 0;
            };
        };

        public func recover_energy(amount: Nat) {
            self.energy := min(self.energy + amount, self.max_energy);
        };
        
        // --- Aksi Kartu ---
        public func basic_attack(target: Kartu) {
            Debug.print("> " # debug_show(self.name) # " menggunakan Basic Attack pada " # debug_show(target.name) # "!");
            target.take_damage(self.attack);
            self.recover_energy(20);
        };

        public func skill(target: Kartu) {
            Debug.print("> " # debug_show(self.name) # " mencoba menggunakan Skill...");
            switch (self.role) {
                case (#Swordman) {
                    if (self.energy >= 40) {
                        Debug.print("  SKILL: Power Strike! (+15 DMG)");
                        target.take_damage(self.attack + 15);
                        self.energy -= 40;
                    } else { Debug.print("  Energi tidak cukup!"); };
                };
                case (#Mage) {
                    if (self.energy >= 35) {
                        let heal = 30;
                        self.hp := min(self.hp + heal, self.max_hp);
                        Debug.print("  SKILL: Heal! (Memulihkan " # Nat.toText(heal) # " HP)");
                        self.energy -= 35;
                    } else { Debug.print("  Energi tidak cukup!"); };
                };
                case _ {
                    Debug.print("  Kartu ini tidak memiliki skill khusus.");
                    self.basic_attack(target);
                };
            };
        };
        
        public func ai_turn(target_list: Buffer.Buffer<Kartu>) {
            if (target_list.size() == 0) { return; };
            let target = target_list.get(Random.range(target_list.size() - 1));
            Debug.print("> " # debug_show(self.name) # " menyerang " # debug_show(target.name) # "!");
            target.take_damage(self.attack);
            self.recover_energy(25);
        };

        public func info(): Text {
            return self.name # " (" # debug_show(self.role) # ") | HP: " # Nat.toText(self.hp) # "/" # Nat.toText(self.max_hp) # " | ATK: " # Nat.toText(self.attack) # " | Energy: " # Nat.toText(self.energy);
        };
    };

    // =====================================================================
    // STATE UTAMA ACTOR
    // =====================================================================

    var player_team: Buffer.Buffer<Kartu> = Buffer.Buffer(0);
    var inventory: Buffer.Buffer<Item> = Buffer.Buffer(0);
    var card_pool: Buffer.Buffer<Kartu> = Buffer.Buffer(0);
    var enemy_pool: [(Text, Role, Nat, Nat, Nat)] = [];
    var boss: ?Kartu = null;
    var current_phase = 1;
    var current_enemies: Buffer.Buffer<Kartu> = Buffer.Buffer(0);

    // =====================================================================
    // FUNGSI INTERNAL
    // =====================================================================
    
    private func setup_pools() {
        card_pool.clear();
        player_team.clear();
        inventory.clear();
        current_phase := 1;

        card_pool.add(Kartu("Kirito", #Swordman, 130, 25, 10));
        card_pool.add(Kartu("Roger", #Archer, 90, 35, 5));
        card_pool.add(Kartu("Karina", #Mage, 100, 30, 8));
        card_pool.add(Kartu("Kratos", #Tank, 180, 15, 15));
        card_pool.add(Kartu("Artemis", #Assassin, 80, 40, 3));
        card_pool.add(Kartu("Celestia", #Priest, 110, 20, 10));
        card_pool.add(Kartu("Grom", #Berserker, 100, 35, 2));
        card_pool.add(Kartu("Jin mu", #Beast, 150, 20, 12));

        enemy_pool = [
            ("Gwigu", #Beast, 80, 15, 5),
            ("Fajrgu", #Beast, 70, 20, 3),
            ("Skeleton", #Undead, 90, 25, 8)
        ];

        boss := ?Kartu("Ancient Dragon", #Dragon, 500, 50, 20);
    };

    private func start_next_phase() {
        current_enemies.clear();
        if (current_phase == 1) {
            let num_enemies = Random.range(4) + 3; // 3-5 musuh
            for (i in 0..num_enemies - 1) {
                let (name, role, hp, attack, defense) = enemy_pool[Random.range(enemy_pool.size() - 1)];
                current_enemies.add(Kartu(name, role, hp, attack, defense));
            };
        } else if (current_phase == 2) {
            let num_enemies = Random.range(6) + 5; // 5-7 musuh
             for (i in 0..num_enemies - 1) {
                let (name, role, hp, attack, defense) = enemy_pool[Random.range(enemy_pool.size() - 1)];
                current_enemies.add(Kartu(name, role, hp + 20, attack + 5, defense + 3));
            };
        } else if (current_phase == 3) {
            switch(boss) {
                case (?b) { current_enemies.add(b); };
                case _ {};
            };
        };
    };

    // =====================================================================
    // FUNGSI PUBLIK (API UNTUK BERMAIN)
    // =====================================================================

    // Memulai atau merestart game
    public shared func startGame(): async Text {
        // Inisialisasi sumber acak
        let pseudo_random_seed = Time.now();
        Random.srand(Text.encodeUtf8(Nat.toText(pseudo_random_seed)));

        setup_pools();
        var response = "Game Dimulai! Pilih 4 kartu untuk tim Anda.\n";
        for (i, card) in card_pool.vals()) {
            response #= Nat.toText(i + 1) # ". " # card.info() # "\n";
        };
        return response;
    };

    // Memilih kartu untuk tim
    public shared func selectCard(card_index: Nat): async Text {
        if (player_team.size() >= 4) {
            return "Tim Anda sudah penuh (4 kartu).";
        };
        if (card_index > 0 and card_index <= card_pool.size()) {
            let chosen_card = card_pool.remove(card_index - 1);
            player_team.add(chosen_card);
            if (player_team.size() == 4) {
                start_next_phase();
                return "Tim terbentuk! Fase 1 dimulai.";
            } else {
                return chosen_card.name # " telah ditambahkan. Sisa " # Nat.toText(4 - player_team.size()) # " kartu lagi.";
            };
        } else {
            return "Indeks kartu tidak valid.";
        };
    };

    // Melihat status permainan saat ini
    public query func getStatus(): async Text {
        var status = "--- STATUS PERMAINAN ---\n";
        status #= "FASE: " # Nat.toText(current_phase) # "\n";
        status #= "\n[ TIM ANDA ]\n";
        for (i, card) in player_team.vals()) {
            status #= Nat.toText(i + 1) # ". " # card.info() # "\n";
        };
        status #= "\n[ MUSUH ]\n";
        for (i, enemy) in current_enemies.vals()) {
            status #= Nat.toText(i + 1) # ". " # enemy.info() # "\n";
        };
        return status;
    };

    // Melakukan aksi di giliran pemain
    public shared func playerAction(player_card_index: Nat, action_type: Text, target_enemy_index: Nat) : async Text {
        if (player_team.size() == 0 or current_enemies.size() == 0) {
            return "Pertarungan sudah berakhir.";
        };

        // 1. Aksi Pemain
        let player_card = player_team.get(player_card_index - 1);
        let target_enemy = current_enemies.get(target_enemy_index - 1);
        
        switch(action_type) {
            case ("basic") { player_card.basic_attack(target_enemy); };
            case ("skill") { player_card.skill(target_enemy); };
            case _ { return "Aksi tidak dikenal."; };
        };

        // Cek jika musuh mati
        if (not target_enemy.is_alive()) {
            Debug.print(target_enemy.name # " telah dikalahkan!");
            current_enemies.remove(target_enemy_index - 1);
        };

        // Cek jika fase berakhir
        if (current_enemies.size() == 0) {
            current_phase += 1;
            if (current_phase > 3) {
                return "SELAMAT! Anda telah memenangkan permainan!";
            };
            start_next_phase();
            return "Fase " # Nat.toText(current_phase - 1) # " selesai! Memasuki Fase " # Nat.toText(current_phase);
        };

        // 2. Aksi Musuh (satu musuh menyerang balik)
        let attacking_enemy = current_enemies.get(Random.range(current_enemies.size() - 1));
        attacking_enemy.ai_turn(player_team);

        // Cek jika kartu pemain mati
        var i = 0;
        while (i < player_team.size()) {
            if (not player_team.get(i).is_alive()) {
                let dead_card = player_team.remove(i);
                Debug.print("!!! " # dead_card.name # " Anda telah dikalahkan !!!");
            } else {
                i += 1;
            };
        };
        
        if (player_team.size() == 0) {
            return "GAME OVER. Semua kartu Anda telah dikalahkan.";
        };

        return "Giliran selesai. Gunakan getStatus() untuk melihat kondisi terbaru.";
    };
}
