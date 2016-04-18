module DocumentDownloads
  include ActionController::Live

  def download_with_options(bucket_name, key_value, content_type = nil, filename = nil)
    uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}##{key_value}"
    begin
      aws_object = Aws::Storage.find_by_uri(uri)
      response.headers['Content-Type'] = get_content_type(params, content_type, aws_object)
      response.headers['Content-Length'] = aws_object.content_length
      response.headers['Content-Disposition'] = get_disposition_and_file_name(params, filename)
      aws_object.get(:response_target => response.stream)
    ensure
      response.stream.close
    end
  end

  protected

  def get_content_type(params, c_type, aws_object)
    return(c_type) unless c_type.blank? 
    params[:content_type].blank? ? aws_object.content_type : params[:content_type]
  end

  def get_disposition_and_file_name(params, file_name)
    disposition_string = params[:disposition].blank? ? "attachment" : params[:disposition]
    return(disposition_string + %(; filename="#{file_name}")) unless file_name.blank?
    disposition_string += disposition_string + %(; filename="#{params[:filename]}") if params[:filename]
    disposition_string
  end
end
