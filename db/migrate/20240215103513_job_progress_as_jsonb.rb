class JobProgressAsJsonb < ActiveRecord::Migration
  def up
    rename_column :delayed_jobs, :progress, :string_progress
    add_column :delayed_jobs, :progress, :jsonb
    up_to_json
    remove_column :delayed_jobs, :string_progress
  end

  def down
    rename_column :delayed_jobs, :progress, :json_progress
    add_column :delayed_jobs, :progress, :jsonb
    down_to_string
    remove_column :delayed_jobs, :json_progress
  end


  def up_to_json
    Delayed::Backend::ActiveRecord::Job.where.not(string_progress: nil).find_each { |job|
      job.update_columns(progress: progress_string_to_json(job.progress))
    }
  end

  def down_to_string
    Delayed::Backend::ActiveRecord::Job.where.not(json_progress: nil).find_each { |job|
      job.update_columns(progress: progress_json_to_string(job.progress))
    }
  end

  def progress_string_to_json(progress)
    return nil unless progress

    splitted = progress.split(';')

    return { 'matrix_progression': 100, 'progression': 100, 'completed': true } if splitted.last == '-1'

    {
      'matrix_progression': splitted.first.to_f,
      'progression': splitted[1].to_f,
      'completed': false
    }
  end

  def progress_json_to_string(progress)
    return nil unless progress


    return "#{progress['matrix_progression']};#{progress['progression']}" unless progress['completed']

    "100;100;-1"
  end
end
