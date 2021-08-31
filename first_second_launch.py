import argparse
import logging
import os
import subprocess
from colorama import Fore

class adb_action:
    logging.basicConfig(level=logging.INFO)
    def __init__(self, folder_path,is_unintall,number_launches):
        self.__FOLDER_PATH = folder_path
        self.__is_uninstall = is_unintall
        self.__number_launches = number_launches
        self.__device_serial = []
        self.__testfile = open(self.__FOLDER_PATH+"/testfile",'wt')
        self.__check_file_determine_installation()
        self.__launch_app_first_launch()
        self.__run_bash_uninstall_script()

    def __get_bundle_id(self, filename):
            logging.info("Attempting extract package ID from {}".format(filename))
            if '.apk' in filename:
                subprocess_return = subprocess.Popen(['aapt2', 'dump', 'packagename', filename],
                                                     stdout=subprocess.PIPE)
                output = subprocess_return.communicate()[0]
            else:
                subprocess_return = subprocess.Popen(
                    ['bundletool', 'dump', 'manifest', '--bundle', filename, '--xpath', '/manifest/@package']
                    , stdout=subprocess.PIPE)
                output = subprocess_return.communicate()[0]
            return output.decode('UTF-8')

    def __check_file_determine_installation(self):
        for filename in os.listdir(self.__FOLDER_PATH):
            if ('.apk' in filename or '.aab' in filename) and 'apks' not in filename:
                file_path = self.__FOLDER_PATH+'/'+filename
                if '.apk' in filename:
                    self.__run_bash_install_apk_script(file_path,self.__get_bundle_id(file_path))
                if '.aab' in filename:
                    self.__run_bash_install_aab_script(file_path,self.__get_bundle_id(file_path))

    def __run_bash_install_apk_script(self,INTSALL_FILE,BUNDLE_ID):
             process=subprocess.Popen(['./apk_install.sh',INTSALL_FILE,BUNDLE_ID],stdout=subprocess.PIPE)
             process.communicate()
             if process.returncode == 0:
                    logging.info(Fore.GREEN + "installation apk done successfully {}".format(BUNDLE_ID))
                    self.__testfile.writelines(BUNDLE_ID)
             else:
                    logging.warning(Fore.YELLOW + "error occurred, check if you had connected device found")
                    exit()

    def __run_bash_install_aab_script(self,INTSALL_FILE,BUNDLE_ID):
            OUTPUT_APKS = INTSALL_FILE.replace('.aab','.apks')
            process = subprocess.Popen(['./aab_install.sh', INTSALL_FILE, BUNDLE_ID,OUTPUT_APKS],stdout=subprocess.PIPE)
            process.communicate()
            if process.returncode == 0:
                    logging.info(Fore.GREEN + "installation aab done successfully {}".format(BUNDLE_ID))
                    self.__testfile.writelines(BUNDLE_ID)
            else:
                logging.warning(Fore.YELLOW + "no connected device found")
                exit()


    def __run_bash_uninstall_script(self):
        if self.__is_uninstall:
            input(Fore.GREEN +"Uninstall is ready, tap 'ENTER' to continue\n")
            for BUNDLE_ID in open(self.__FOLDER_PATH+"/testfile",'rt'):
                process = subprocess.Popen(['./adb_uninstall.sh',BUNDLE_ID], stdout=subprocess.PIPE)
                process.communicate()
                if process.returncode == 0:
                    logging.info("uninstall done successfully {}".format(BUNDLE_ID))
            exit()


    def __launch_app_first_launch(self):
        self.__testfile.close()
        for BUNDLE_ID in open(self.__FOLDER_PATH+"/testfile",'rt'):
                proc = subprocess.Popen(['./android_loop_launch.sh',BUNDLE_ID,self.__FOLDER_PATH,self.__number_launches])
                proc.wait()
                logging.info("First second launch automation has done\n check the outcomes in {}".format(self.__FOLDER_PATH))

def main():
    """
    parse arguments, validate them
    """
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--folder', required=True,
                        help="your apks folder")
    parser.add_argument('-u', '--uninstall', required=False,default=False,
                        help="uninstall apps after automation has done")
    parser.add_argument('-l', '--launch', required=False,default='2',
                        help="number of launches for each app")
    arguments = parser.parse_args()
    if (not arguments.folder):
        logging.error('at least one type of test needs to be specified')
        exit()
    if str(arguments.uninstall).lower() == 'true':
        arguments.uninstall = True

    elif arguments.uninstall == False:
            pass
    else:
        logging.error("specify 'true' to uninstall the apps")
        exit()
    adb_action(arguments.folder,arguments.uninstall,arguments.launch)

if __name__ == '__main__':
    main()