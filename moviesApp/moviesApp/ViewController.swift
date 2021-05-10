//
//  ViewController.swift
//  moviesApp
//
//  Created by Katie Johnston on 5/2/21.
//  Created the week before the due date, but I was doing lots of research :)
//
//  Key Goals for this App
//  1: Display Dad's Movies (in TableView) - Done
//  2: Add/Delete Movies - Done
//  3: Create custom icon - Done
//  4: Splash Screen - Done
//  Tech-Stack: SQLite, Swift
//  Optimized for iPad

import UIKit
import SQLite3

class ViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {

    var db: OpaquePointer?
    var movieList = [Movie]()

    @IBOutlet weak var movieName: UITextField!
    @IBOutlet weak var movieLocation: UITextField!
    @IBOutlet weak var bluRayTable: UITableView!
    @IBOutlet weak var btnSave: UIButton!
    
    let cellID = "cellID"
    //func for saving new movies
    @IBAction func btnSave(_ sender: UIButton) {
        //This function will allow a user to save some movies, runs an insert query for adding the movies to the database and tableview, then refreshes the tableview with the new movie
        let name = movieName.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        var binder = movieLocation.text?.trimmingCharacters(in: .whitespacesAndNewlines)
  
        //values cannot be empty, change colors to show that
        if(name?.isEmpty)! || (binder?.isEmpty)! {
            movieName.backgroundColor = UIColor.red
            movieLocation.backgroundColor = UIColor.red
            return
        }else{
            //Once this is corrected, it reverts back to white
            movieName.backgroundColor = UIColor.white
            movieLocation.backgroundColor = UIColor.white
        }
        
        //While I prevent a blank text from being saved, this was the best way I could find to only allow numbers to save in case someone enters in a bunch of text.
        binder = binder?.filter("0123456789.".contains)
        //If only non-numbers were entered, it defaults to zero.
        
        //creating a statement
        var stmt: OpaquePointer?
 
        //the insert query
        let queryString = "INSERT INTO bluRays (name, binder) VALUES (?,?)"
 
        //preparing the query
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing insert: \(errmsg)")
            return
        }
 
        //binding the movie name
        if sqlite3_bind_text(stmt, 1, name, -1, nil) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure binding name: \(errmsg)")
            return
        }
 
        //binding the movie location
        if sqlite3_bind_int(stmt, 2, (binder! as NSString).intValue) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure inserting name: \(errmsg)")
            return
        }
 
        //executing the query to insert values
        if sqlite3_step(stmt) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure inserting binder: \(errmsg)")
            return
        }

        //emptying the text
        movieName.text=""
        movieLocation.text=""
        readValues()

        print("Movie saved successfully")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //All it does is return a count of movies from the movie list, I think this is to gather the number of cells to make based on what's in the database
        return movieList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //This function populates the cells in the table view with info from the database
        var cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: cellID)
        let movie: Movie
        movie = movieList[indexPath.row]
        cell.textLabel?.text = movie.name
        cell.detailTextLabel?.text = "Volume: " + String(movie.binder)
        return cell
    }
    
    //My delete function, in a swiping fashion
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            deleteMovieItem(id: Int32(movieList[indexPath.row].id))
            readValues()
        }
    }
    
    //This runs the delete query for the above delete function
    func deleteMovieItem(id: Int32){
        let deleteStatementStirng = "DELETE FROM bluRays WHERE id = ?;"
        var deleteStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, deleteStatementStirng, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStatement, 1, id)
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                print("Successfully deleted row.") //Success
            } else {
                print("Could not delete row.") //Something went wrong
            }
        } else {
            print("DELETE statement could not be prepared")
        }
        sqlite3_finalize(deleteStatement)
        print("delete") //Just to remind me that I'm successful :)
    }
    
    func readValues() {
        movieList.removeAll()
        
        let queryString = "SELECT * FROM bluRays"
        
        var stmt: OpaquePointer?
        
        //prep statement
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing insert \(errmsg)")
            return
        }
        
        //moving through the movies
        while(sqlite3_step(stmt) == SQLITE_ROW){
            let id = sqlite3_column_int(stmt, 0)
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let binder = sqlite3_column_int(stmt, 2)
            
            //gonna add me a lot of bluRays
            movieList.append(Movie(id: Int(id), name: String(describing: name), binder: Int(binder)))
        }
        self.bluRayTable.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view. This is where I load everything
        
        bluRayTable.delegate = self
        bluRayTable.dataSource = self
        
        //declare file for bluRayMovies sqlite database
        let fileURL = try!FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("bluRays.sqlite")
        
        //in case of fail
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK{
            print("Error opening the database")
            return
        }
        
        //create the database (for first time users)
        let createTableQuery = "CREATE TABLE IF NOT EXISTS bluRays (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, binder INTEGER)"
        
        //throw if fail
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK{
            print("Error creating table")
            return
        }
        
        //but if successful
        print("You are Gucci - table and database are made")
        readValues()
    }
}

//This class is for reading the movies - create movie instance and initialize it
class Movie {
    var id: Int
    var name: String?
    var binder: Int
    
    init(id: Int, name: String?, binder: Int){
        self.id = id
        self.name = name
        self.binder = binder
    }
}


